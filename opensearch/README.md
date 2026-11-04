<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_opensearch"></a> [opensearch](#module\_opensearch) | git::https://github.com/leanspace/platform-infra-modules.git//aws/opensearch | main |
| <a name="module_opensearch_kms_key"></a> [opensearch\_kms\_key](#module\_opensearch\_kms\_key) | git::https://github.com/leanspace/platform-infra-modules.git//aws/kms | main |
| <a name="module_vault_export"></a> [vault\_export](#module\_vault\_export) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [terraform_remote_state.networking](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_component_category"></a> [component\_category](#input\_component\_category) | The category of the component being deployed | `string` | `"platform-infrastructure"` | no |
| <a name="input_component_type"></a> [component\_type](#input\_component\_type) | The name of the type of component being deployed | `string` | `"opensearch-cluster"` | no |
| <a name="input_data_node_count"></a> [data\_node\_count](#input\_data\_node\_count) | Number of data nodes (Only applicable if mode is CUSTOM) | `number` | `null` | no |
| <a name="input_data_node_type"></a> [data\_node\_type](#input\_data\_node\_type) | Instance type for data nodes (Only applicable if mode is CUSTOM) | `string` | `null` | no |
| <a name="input_deployment_mode"></a> [deployment\_mode](#input\_deployment\_mode) | The mode of deployment for the OpenSearch cluster (PROD, DEV, or CUSTOM) | `string` | n/a | yes |
| <a name="input_high_availability"></a> [high\_availability](#input\_high\_availability) | Enable high availability for the OpenSearch cluster | `bool` | `false` | no |
| <a name="input_master_node_type"></a> [master\_node\_type](#input\_master\_node\_type) | Instance type for master nodes (Only applicable if mode is CUSTOM) | `string` | `null` | no |
| <a name="input_opensearch_tls_security_policy"></a> [opensearch\_tls\_security\_policy](#input\_opensearch\_tls\_security\_policy) | TLS security policy for OpenSearch | `string` | `"Policy-Min-TLS-1-2-2019-07"` | no |
| <a name="input_opensearch_version"></a> [opensearch\_version](#input\_opensearch\_version) | Version of OpenSearch to deploy | `string` | `"OpenSearch_2.11"` | no |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Team name tag for the opensearch cluster | `string` | `"silver"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the OpenSearch cluster |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Endpoint of the OpenSearch cluster |
| <a name="output_name"></a> [name](#output\_name) | Name of the OpenSearch cluster |
<!-- END_TF_DOCS -->