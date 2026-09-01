terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "queue" {
  source = "../../"

  name = "iacbazaar-example-orders"

  producer_arns = ["arn:aws:iam::123456789012:role/example-producer"]
  consumer_arns = ["arn:aws:iam::123456789012:role/example-consumer"]

  service_publishers = {
    sns = {
      service    = "sns.amazonaws.com"
      source_arn = "arn:aws:sns:us-east-1:123456789012:example-topic"
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "iac-bazaar"
  }
}

output "queue_url" {
  value = module.queue.queue_url
}

output "dlq_arn" {
  value = module.queue.dlq_arn
}
