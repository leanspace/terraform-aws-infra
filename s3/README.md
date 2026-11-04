# AWS S3

Provisions the platform's S3 buckets, each individually toggleable and disabled by default.

## Usage

Every bucket this component knows about (see `local.known_bucket_names` in
`main.tf`) defaults to disabled. To turn specific ones on for an environment,
add an `environment-tfvars/<environment_name>.tfvars` file (see other
components for the convention) that sets `s3_buckets`, keyed by the known
bucket's name:

```hcl
s3_buckets = {
  # Turn on a known bucket, keeping all its other defaults (versioning,
  # encryption, etc.) as-is.
  "logs-chunks" = {
    enabled = true
  }

  # A brand-new, ad-hoc bucket this component doesn't know about by
  # default -- any key that isn't one of the known bucket names works the
  # same way.
  "my-custom-exports" = {
    enabled       = true
    name          = "totally-custom-bucket-name"
    sse_algorithm = "AES256"
    policy_json   = jsonencode({
      Version   = "2012-10-17"
      Statement = []
    })
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_bucket"></a> [bucket](#module\_bucket) | git::https://github.com/leanspace/platform-infra-modules.git//aws/s3/bucket | main |
| <a name="module_vault_export"></a> [vault\_export](#module\_vault\_export) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_component_category"></a> [component\_category](#input\_component\_category) | The category of the component being deployed | `string` | `"platform-infrastructure"` | no |
| <a name="input_component_type"></a> [component\_type](#input\_component\_type) | The name of the type of component being deployed | `string` | `"s3"` | no |
| <a name="input_s3_buckets"></a> [s3\_buckets](#input\_s3\_buckets) | Map of S3 buckets to manage, keyed by a short logical name. Several keys<br/>are already known (the buckets the platform uses today, see<br/>local.known\_bucket\_names in main.tf) and default to disabled; reusing one<br/>of those keys here overrides its fields (most commonly just<br/>`enabled = true`). Any other key creates a brand-new, ad-hoc bucket the<br/>same way. Every bucket, known or ad-hoc, defaults to disabled unless<br/>explicitly enabled. | <pre>map(object({<br/>    enabled            = optional(bool, false)<br/>    name               = optional(string)<br/>    versioning_enabled = optional(bool, true)<br/>    force_destroy      = optional(bool, false)<br/>    sse_algorithm      = optional(string, "aws:kms")<br/>    kms_key_arn        = optional(string)<br/>    lifecycle_rule     = optional(any, [])<br/>    policy_json        = optional(string)<br/>    tags               = optional(map(string), {})<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Map of logical bucket name to its ARN, for every enabled bucket |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | Map of logical bucket name to its actual S3 bucket name, for every enabled bucket |
<!-- END_TF_DOCS -->
