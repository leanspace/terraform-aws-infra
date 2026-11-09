locals {
  s3_tags = {
    component-category = var.component_category
    component-type     = "s3"
    environment        = var.environment
    managed-by         = "terraform"
  }

  known_bucket_names = [
    "logs-chunks",
    "logs-ruler",
    "logs-admin",
    "logs-thanos",
    "traces-tempo",
    "postgres-backups",
    "allure-reports",
    "processor",
    "records-uploads",
    "plugins-source-code-files",
    "plugins-test-executions",
    "file",
    "stream-decoders",
    "create-stream-request",
  ]

  bucket_defaults = {
    enabled            = false
    name               = null
    versioning_enabled = true
    force_destroy      = false
    sse_algorithm      = "aws:kms"
    kms_key_arn        = null
    lifecycle_rule     = []
    policy_json        = null
    tags               = {}
  }

  # Known buckets whose defaults should differ from bucket_defaults above --
  # short-lived observability data, point-in-time database backups, and
  # test-report artifacts don't benefit from object versioning the way
  # genuinely user-uploaded/user-generated content does.
  known_bucket_overrides = {
    logs-chunks      = { versioning_enabled = false }
    logs-ruler       = { versioning_enabled = false }
    logs-admin       = { versioning_enabled = false }
    logs-thanos      = { versioning_enabled = false }
    traces-tempo     = { versioning_enabled = false }
    postgres-backups = { versioning_enabled = false }
    allure-reports   = { versioning_enabled = false }
  }

  known_bucket_defaults = {
    for name in local.known_bucket_names :
    name => merge(local.bucket_defaults, lookup(local.known_bucket_overrides, name, {}))
  }

  all_bucket_keys = toset(concat(local.known_bucket_names, keys(var.s3_buckets)))
  all_buckets = {
    for k in local.all_bucket_keys : k => (
      contains(keys(var.s3_buckets), k) ? merge(var.s3_buckets[k], {
        # versioning_enabled is nullable on the variable specifically so a
        # tfvars override that doesn't mention it (e.g. just `{ enabled =
        # true }`) still gets this bucket's category-appropriate default
        # instead of silently falling back to `true`.
        versioning_enabled = coalesce(
          var.s3_buckets[k].versioning_enabled,
          lookup(local.known_bucket_defaults, k, local.bucket_defaults).versioning_enabled
        )
      }) : local.known_bucket_defaults[k]
    )
  }
  enabled_buckets = { for k, v in local.all_buckets : k => v if v.enabled }
}

module "bucket" {
  source   = "git::https://github.com/leanspace/terraform-aws-modules.git//s3/bucket?ref=v0.1.3"
  for_each = local.enabled_buckets

  bucket_name        = coalesce(each.value.name, "${var.resource_prefix}-${var.environment}-${each.key}")
  versioning_enabled = each.value.versioning_enabled
  force_destroy      = each.value.force_destroy
  sse_algorithm      = each.value.sse_algorithm
  kms_key_arn        = each.value.kms_key_arn
  lifecycle_rule     = each.value.lifecycle_rule
  policy_json        = each.value.policy_json
  tags               = merge(local.s3_tags, each.value.tags)
}

module "vault_export_s3" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    for k, m in module.bucket : {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/s3_${k}_arn"
      data  = { value = m.arn }
    }
  ] : []
}
