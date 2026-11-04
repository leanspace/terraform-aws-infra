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
| <a name="module_db_kms_key"></a> [db\_kms\_key](#module\_db\_kms\_key) | git::https://github.com/leanspace/platform-infra-modules.git//aws/kms | main |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | git::https://github.com/leanspace/platform-infra-modules.git//aws/database | main |
| <a name="module_vault_export"></a> [vault\_export](#module\_vault\_export) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_security_group_rule.postgres_self_reference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [terraform_remote_state.kube-cluster](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.networking](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aurora_engine_version"></a> [aurora\_engine\_version](#input\_aurora\_engine\_version) | Aurora PostgreSQL engine version | `string` | `"14.13"` | no |
| <a name="input_aurora_instances"></a> [aurora\_instances](#input\_aurora\_instances) | Map of Aurora instances | `map(any)` | <pre>{<br/>  "1": {<br/>    "auto_minor_version_upgrade": false,<br/>    "ca_cert_identifier": "rds-ca-ecc384-g1",<br/>    "db_parameter_group_name": "default.aurora-postgresql14",<br/>    "instance_class": "db.t3.medium",<br/>    "performance_insights_enabled": true,<br/>    "publicly_accessible": false<br/>  }<br/>}</pre> | no |
| <a name="input_component_category"></a> [component\_category](#input\_component\_category) | The category of the component being deployed | `string` | `"platform-infrastructure"` | no |
| <a name="input_component_type"></a> [component\_type](#input\_component\_type) | The name of the type of component being deployed | `string` | `"database-cluster"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true` | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Team name tag for the db cluster | `string` | `"silver"` | no |
| <a name="input_via_service"></a> [via\_service](#input\_via\_service) | AWS service that is using the KMS key (e.g., 'rds') | `string` | `"rds"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_aurora_db_cluster_identifier"></a> [aurora\_db\_cluster\_identifier](#output\_aurora\_db\_cluster\_identifier) | The identifier of the Aurora DB cluster. |
| <a name="output_aurora_db_endpoint"></a> [aurora\_db\_endpoint](#output\_aurora\_db\_endpoint) | The endpoint of the Aurora DB cluster. |
| <a name="output_aurora_db_port"></a> [aurora\_db\_port](#output\_aurora\_db\_port) | The port of the Aurora DB cluster. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The ARN of the Aurora DB cluster. |
| <a name="output_key_aliases"></a> [key\_aliases](#output\_key\_aliases) | List of aliases created for the KMS key. |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | The Amazon Resource Name (ARN) of the KMS key. |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | The globally unique identifier for the KMS key. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The security group ID of the Aurora DB. |
<!-- END_TF_DOCS -->