variable "component_category" {
  description = "The category of the component being deployed"
  type        = string
  default     = "platform-infrastructure"
}

variable "component_type" {
  description = "The name of the type of component being deployed"
  type        = string
  default     = "s3"
}

variable "s3_buckets" {
  description = <<-EOT
    Map of S3 buckets to manage, keyed by a short logical name. Several keys
    are already known (the buckets the platform uses today, see
    local.known_bucket_names in main.tf) and default to disabled; reusing one
    of those keys here overrides its fields (most commonly just
    `enabled = true`). Any other key creates a brand-new, ad-hoc bucket the
    same way. Every bucket, known or ad-hoc, defaults to disabled unless
    explicitly enabled.

    versioning_enabled is left unset (null) rather than defaulting here so
    that enabling a known bucket (e.g. `{ enabled = true }`) doesn't silently
    override that bucket's category-appropriate default from
    local.known_bucket_overrides in main.tf -- set it explicitly to override
    that default either way.
  EOT
  type = map(object({
    enabled            = optional(bool, false)
    name               = optional(string)
    versioning_enabled = optional(bool)
    force_destroy      = optional(bool, false)
    sse_algorithm      = optional(string, "aws:kms")
    kms_key_arn        = optional(string)
    lifecycle_rule     = optional(any, [])
    policy_json        = optional(string)
    tags               = optional(map(string), {})
  }))
  default = {}
}
