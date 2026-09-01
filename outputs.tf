output "queue_url" {
  description = "URL of the main queue."
  value       = aws_sqs_queue.this.url
}

output "queue_arn" {
  description = "ARN of the main queue."
  value       = aws_sqs_queue.this.arn
}

output "queue_name" {
  description = "Final name of the main queue (including any .fifo suffix)."
  value       = aws_sqs_queue.this.name
}

output "dlq_url" {
  description = "URL of the dead-letter queue; null when create_dlq = false."
  value       = try(aws_sqs_queue.dlq[0].url, null)
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue; null when create_dlq = false."
  value       = try(aws_sqs_queue.dlq[0].arn, null)
}

output "dlq_name" {
  description = "Final name of the dead-letter queue; null when create_dlq = false."
  value       = try(aws_sqs_queue.dlq[0].name, null)
}
