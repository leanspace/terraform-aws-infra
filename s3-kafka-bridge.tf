# S3 -> SQS -> Kafka for bucket events (AWS S3 can't publish to Kafka, unlike RustFS).
# aws_s3_bucket_notification replaces each bridged bucket's whole notification config.
#
# Reuses data.aws_eks_cluster.this and data.aws_iam_openid_connect_provider.oidc from
# eks.tf, and data.aws_caller_identity.current from common.tf - this was originally its
# own Terraform root (with its own copies of both data sources), folded in here the same
# way every other component was.
locals {
  s3_kafka_bridge_tags = {
    component-category = var.component_category
    component-type     = "s3-kafka-bridge"
    environment        = var.environment
    managed-by         = "terraform"
    team               = var.team_name
  }

  s3_kafka_bridge_name = "leanspace-${var.environment}-s3-kafka-bridge"

  s3_kafka_bridge_buckets = toset([for b in values(var.s3_kafka_bridges) : b.bucket])

  # Queue ARN/URL per bridge, regardless of whether this root created the queue or it
  # already existed (e.g. from CloudFormation, same pattern as services_s3_bucket_names'
  # pre-existing buckets - during the agnostic migration these queues already exist).
  # Everything downstream (policy, notification, IRSA, vault export) only needs the
  # ARN/URL, so only the queue resources themselves need the toggle.
  s3_kafka_bridge_queue_arns = var.s3_kafka_bridge_queues_exist ? {
    for k, q in data.aws_sqs_queue.s3_kafka_bridge_existing : k => q.arn
    } : {
    for k, q in aws_sqs_queue.s3_kafka_bridge : k => q.arn
  }
  s3_kafka_bridge_queue_urls = var.s3_kafka_bridge_queues_exist ? {
    for k, q in data.aws_sqs_queue.s3_kafka_bridge_existing : k => q.url
    } : {
    for k, q in aws_sqs_queue.s3_kafka_bridge : k => q.url
  }
}

data "aws_s3_bucket" "s3_kafka_bridge" {
  for_each = local.s3_kafka_bridge_buckets
  bucket   = each.value
}

data "aws_sqs_queue" "s3_kafka_bridge_existing" {
  for_each = var.s3_kafka_bridge_queues_exist ? var.s3_kafka_bridges : {}
  name     = "leanspace-${var.environment}-${each.key}"
}

# Redrive policy on a pre-existing queue is assumed already configured (by whatever
# created it) - not managed here when s3_kafka_bridge_queues_exist is true.
resource "aws_sqs_queue" "s3_kafka_bridge_dlq" {
  for_each = var.s3_kafka_bridge_queues_exist ? {} : var.s3_kafka_bridges

  name                      = "leanspace-${var.environment}-${each.key}-dead-letter"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags                      = local.s3_kafka_bridge_tags
}

resource "aws_sqs_queue" "s3_kafka_bridge" {
  for_each = var.s3_kafka_bridge_queues_exist ? {} : var.s3_kafka_bridges

  name                       = "leanspace-${var.environment}-${each.key}"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.s3_kafka_bridge_dlq[each.key].arn
    maxReceiveCount     = 5
  })

  tags = local.s3_kafka_bridge_tags
}

resource "aws_sqs_queue_policy" "s3_kafka_bridge" {
  for_each = var.s3_kafka_bridges

  queue_url = local.s3_kafka_bridge_queue_urls[each.key]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBucketNotifications"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = local.s3_kafka_bridge_queue_arns[each.key]
        Condition = {
          ArnEquals    = { "aws:SourceArn" = data.aws_s3_bucket.s3_kafka_bridge[each.value.bucket].arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "s3_kafka_bridge" {
  for_each = local.s3_kafka_bridge_buckets

  bucket = each.value

  dynamic "queue" {
    for_each = { for k, v in var.s3_kafka_bridges : k => v if v.bucket == each.value }
    content {
      id            = queue.key
      queue_arn     = local.s3_kafka_bridge_queue_arns[queue.key]
      events        = queue.value.events
      filter_prefix = queue.value.filter_prefix
      filter_suffix = queue.value.filter_suffix
    }
  }

  # S3 validates it can send to each queue when the notification is created.
  depends_on = [aws_sqs_queue_policy.s3_kafka_bridge]
}

module "s3_kafka_bridge_irsa_role" {
  count = length(var.s3_kafka_bridges) > 0 ? 1 : 0

  source = "git::https://github.com/leanspace/terraform-aws-modules.git//iam/irsa-role?ref=v0.1.5"

  role_name   = local.s3_kafka_bridge_name
  policy_name = local.s3_kafka_bridge_name
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ConsumeBridgeQueues"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
        ]
        Resource = values(local.s3_kafka_bridge_queue_arns)
      }
    ]
  })

  oidc_provider_arn = data.aws_iam_openid_connect_provider.oidc.arn
  oidc_provider_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  service_account_subjects = [var.s3_kafka_bridge_service_account]

  tags = local.s3_kafka_bridge_tags
}

# Read by platform-delivery's export-deploy-secrets action.
module "vault_export_s3_kafka_bridge" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export && length(var.s3_kafka_bridges) > 0 ? concat(
    [
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/s3_kafka_bridge_role_arn"
        data  = { value = module.s3_kafka_bridge_irsa_role[0].role_arn }
      }
    ],
    [
      for k, url in local.s3_kafka_bridge_queue_urls : {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/s3_kafka_bridge_${k}_queue_url"
        data  = { value = url }
      }
    ]
  ) : []
}
