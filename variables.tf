variable "name" {
  description = "Queue name. For FIFO queues the .fifo suffix is appended automatically if missing."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,70}(\\.fifo)?$", var.name))
    error_message = "name must be 1-70 characters of [a-zA-Z0-9_-] (an optional .fifo suffix is allowed; it is added automatically for FIFO queues)."
  }
}

variable "fifo_queue" {
  description = "Create a FIFO queue (and FIFO DLQ). Naming suffixes are handled automatically."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "FIFO only: deduplicate on a SHA-256 of the message body instead of an explicit deduplication id."
  type        = bool
  default     = false
}

variable "deduplication_scope" {
  description = "FIFO only: deduplication scope (queue or messageGroup). messageGroup is required for high-throughput FIFO."
  type        = string
  default     = "queue"

  validation {
    condition     = contains(["queue", "messageGroup"], var.deduplication_scope)
    error_message = "deduplication_scope must be queue or messageGroup."
  }
}

variable "fifo_throughput_limit" {
  description = "FIFO only: throughput quota scope (perQueue or perMessageGroupId). perMessageGroupId enables high-throughput FIFO."
  type        = string
  default     = "perQueue"

  validation {
    condition     = contains(["perQueue", "perMessageGroupId"], var.fifo_throughput_limit)
    error_message = "fifo_throughput_limit must be perQueue or perMessageGroupId."
  }
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout. Set to at least 6x your consumer's processing time (Lambda: 6x function timeout)."
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200."
  }
}

variable "message_retention_seconds" {
  description = "How long the main queue retains messages (default 4 days, max 14 days)."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 and 1209600."
  }
}

variable "max_message_size" {
  description = "Maximum message size in bytes."
  type        = number
  default     = 262144

  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 262144
    error_message = "max_message_size must be between 1024 and 262144."
  }
}

variable "delay_seconds" {
  description = "Default per-queue delivery delay."
  type        = number
  default     = 0

  validation {
    condition     = var.delay_seconds >= 0 && var.delay_seconds <= 900
    error_message = "delay_seconds must be between 0 and 900."
  }
}

variable "receive_wait_time_seconds" {
  description = "Long-polling wait time. 10s by default: fewer empty receives, lower cost; set 0 for short polling."
  type        = number
  default     = 10

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "receive_wait_time_seconds must be between 0 and 20."
  }
}

variable "kms_key_id" {
  description = "Customer-managed KMS key (id, alias, or ARN) for SSE-KMS. Null = SQS-managed SSE (still encrypted at rest)."
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period_seconds" {
  description = "How long SQS may reuse a data key before calling KMS again (only with kms_key_id)."
  type        = number
  default     = 300

  validation {
    condition     = var.kms_data_key_reuse_period_seconds >= 60 && var.kms_data_key_reuse_period_seconds <= 86400
    error_message = "kms_data_key_reuse_period_seconds must be between 60 and 86400."
  }
}

# ---------------------------------------------------------------------------
# Dead-letter queue
# ---------------------------------------------------------------------------

variable "create_dlq" {
  description = "Create a dead-letter queue and wire the redrive + redrive-allow policies."
  type        = bool
  default     = true
}

variable "dlq_name" {
  description = "Override the DLQ name. Defaults to <name>-dlq (with .fifo handling for FIFO queues)."
  type        = string
  default     = null
}

variable "max_receive_count" {
  description = "Receives before a message is moved to the DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
}

variable "dlq_message_retention_seconds" {
  description = "DLQ retention (default 14 days, the maximum -- dead letters need investigation time)."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be between 60 and 1209600."
  }
}

# ---------------------------------------------------------------------------
# Queue policy
# ---------------------------------------------------------------------------

variable "create_queue_policy" {
  description = "Attach the module's queue policies (TLS-only deny + allow-listed principals). Disable only if you manage aws_sqs_queue_policy yourself."
  type        = bool
  default     = true
}

variable "producer_arns" {
  description = "IAM principal ARNs allowed to send messages (sqs:SendMessage)."
  type        = list(string)
  default     = []
}

variable "consumer_arns" {
  description = "IAM principal ARNs allowed to receive/delete messages."
  type        = list(string)
  default     = []
}

variable "service_publishers" {
  description = "AWS services allowed to publish, pinned to a source ARN. Example: { sns = { service = \"sns.amazonaws.com\", source_arn = aws_sns_topic.t.arn } }."
  type = map(object({
    service    = string
    source_arn = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
