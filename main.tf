# SQS queue (standard or FIFO) with a dead-letter queue, redrive wiring,
# server-side encryption always on, and a TLS-only least-privilege queue
# policy. FIFO naming (.fifo suffix on queue and DLQ) is handled for you.

locals {
  queue_name = var.fifo_queue ? (endswith(var.name, ".fifo") ? var.name : "${var.name}.fifo") : var.name
  base_name  = trimsuffix(local.queue_name, ".fifo")
  dlq_name   = coalesce(var.dlq_name, var.fifo_queue ? "${local.base_name}-dlq.fifo" : "${local.base_name}-dlq")
}

# ---------------------------------------------------------------------------
# Queues
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "this" {
  name       = local.queue_name
  fifo_queue = var.fifo_queue

  # FIFO-only knobs are nulled on standard queues so plans stay clean.
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  deduplication_scope         = var.fifo_queue ? var.deduplication_scope : null
  fifo_throughput_limit       = var.fifo_queue ? var.fifo_throughput_limit : null

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  # Encryption at rest is always on: customer KMS key when provided,
  # SQS-managed SSE otherwise.
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_key_id != null ? var.kms_data_key_reuse_period_seconds : null
  sqs_managed_sse_enabled           = var.kms_key_id == null ? true : null

  tags = var.tags
}

resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name       = local.dlq_name
  fifo_queue = var.fifo_queue

  # Keep dead letters as long as possible (14 days) by default: messages land
  # here because something is broken, and you want time to redrive them.
  message_retention_seconds = var.dlq_message_retention_seconds

  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_key_id != null ? var.kms_data_key_reuse_period_seconds : null
  sqs_managed_sse_enabled           = var.kms_key_id == null ? true : null

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Redrive wiring (standalone resources so the DLQ relationship is explicit)
# ---------------------------------------------------------------------------

resource "aws_sqs_queue_redrive_policy" "this" {
  count = var.create_dlq ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Lock the DLQ so only this queue may use it as a dead-letter target.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  count = var.create_dlq ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

# ---------------------------------------------------------------------------
# Queue policies: deny non-TLS always; allow-list producers/consumers and
# service publishers (SNS, S3, EventBridge, ...) pinned to their source ARN.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "queue" {
  count = var.create_queue_policy ? 1 : 0

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = length(var.producer_arns) > 0 ? [1] : []
    content {
      sid       = "AllowProducers"
      effect    = "Allow"
      actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "AWS"
        identifiers = var.producer_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.consumer_arns) > 0 ? [1] : []
    content {
      sid       = "AllowConsumers"
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "AWS"
        identifiers = var.consumer_arns
      }
    }
  }

  dynamic "statement" {
    for_each = var.service_publishers
    content {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "Service"
        identifiers = [statement.value.service]
      }

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [statement.value.source_arn]
      }
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  count = var.create_queue_policy ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.queue[0].json
}

data "aws_iam_policy_document" "dlq" {
  count = var.create_dlq && var.create_queue_policy ? 1 : 0

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.dlq[0].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq" {
  count = var.create_dlq && var.create_queue_policy ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id
  policy    = data.aws_iam_policy_document.dlq[0].json
}
