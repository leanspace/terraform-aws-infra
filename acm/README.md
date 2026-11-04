<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_agnostk_certificate"></a> [agnostk\_certificate](#module\_agnostk\_certificate) | git::https://github.com/leanspace/platform-infra-modules.git//aws/acm | main |
| <a name="module_vault_export"></a> [vault\_export](#module\_vault\_export) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alternative_names"></a> [alternative\_names](#input\_alternative\_names) | List of alternative domain names for the certificate | `list(string)` | `[]` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for the certificate | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the certificate for agnostk.leanspace.io |
<!-- END_TF_DOCS -->