# terraform-aws-infra

AWS infrastructure for the Leanspace platform: ACM, Aurora Postgres, EKS, networking (VPC),
OpenSearch, and S3, as a **single Terraform root with a single state**.

## Structure

Each component calls the shared modules in
[platform-infra-modules](https://github.com/leanspace/platform-infra-modules) directly -
there is no local wrapper module per component. One file per component, all in this one
root:

| File | Component |
| --- | --- |
| `acm.tf` | ACM certificate |
| `rds.tf` | Aurora Postgres + its KMS key (`rds-kms-policy.json.tpl`) |
| `eks.tf` | EKS cluster, node groups, addons, IRSA roles |
| `networking.tf` | VPC, subnets, flow logs, endpoints, VPC Lattice |
| `opensearch.tf` | OpenSearch domain + its KMS key (`opensearch-kms-policy.json.tpl`) |
| `s3.tf` | Platform S3 buckets (toggleable, disabled by default) |

Plus root-level `variables.tf`, `outputs.tf`, `versions.tf` (required providers + the
Vault-backed HTTP backend), `provider.tf`, and `common.tf` (data sources shared by more
than one component).

Components reference each other's resources directly (e.g. `rds.tf` uses
`module.vpc.vpc_id` and `module.eks_cluster.node_security_group_id`) instead of reading
another root's state over `terraform_remote_state` - there's only one state now.

## This used to be 6 separate roots

Until recently, `acm/`, `database/`, `eks/`, `networking/`, `opensearch/`, and `s3/` were
each an independently-applied Terraform root (own state, own CI job in
`platform-infrastructure`'s `deploy-to-aws.yml`), stitched together with
`terraform_remote_state` reads. They've been consolidated into this single root. See
[`docs/state-migration-runbook.md`](./docs/state-migration-runbook.md) for the plan to
migrate each environment's existing state into the new combined state - **no live state
has been migrated yet**; this repo is file-level-only until that runbook is run.

The CI workflow that applies these components (`platform-infrastructure`'s
`deploy-to-aws.yml`, currently 6 separate jobs) has **not** been updated yet - that's
pending internal team sign-off on this restructuring.

## Environments

`environment-tfvars/<environment_name>.tfvars` holds the per-environment overrides (one
file per environment, merged across what used to be per-component tfvars). These are
gitignored (real VPC/subnet IDs, bucket names, etc. in a public repo) - copy
`environment-tfvars/example.tfvars.example` to get started. `agnostk` is the sandbox
account; `develop` currently only carries EKS overrides.

## Disabling a component

`enable_networking`, `enable_acm`, `enable_database`, and `enable_opensearch` (all
default `true`) skip creating that component entirely. This matters most for
`enable_networking`: during the agnostic migration, `agnostk`'s VPC already exists from
a CloudFormation stack and this root shouldn't create a second one. Set
`enable_networking = false` and pass the existing VPC directly via `vpc_id` /
`private_subnets` / `public_subnets` - every component that needs VPC info (`eks.tf`,
`rds.tf`, `opensearch.tf`) resolves it through `local.vpc_id` / `local.private_subnets`
in `common.tf`, which fall back to those variables instead of reading `module.vpc`
directly. A validation rule enforces that `vpc_id` is set whenever
`enable_networking = false`. EKS itself doesn't have a toggle - it's assumed to always
be deployed - and S3 is already opt-in per bucket (see above), so it doesn't need one
either.

## Enabling an S3 bucket

Every bucket this component knows about (see `local.known_bucket_names` in `s3.tf`)
defaults to disabled. To turn specific ones on for an environment, add an entry to that
environment's tfvars that sets `s3_buckets`, keyed by the known bucket's name:

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
    policy_json = jsonencode({
      Version   = "2012-10-17"
      Statement = []
    })
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | 2.7.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.95.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.5 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.13.1 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.95.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.5 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_agnostk_certificate"></a> [agnostk\_certificate](#module\_agnostk\_certificate) | git::https://github.com/leanspace/terraform-aws-modules.git//acm | main |
| <a name="module_bucket"></a> [bucket](#module\_bucket) | git::https://github.com/leanspace/terraform-aws-modules.git//s3/bucket | main |
| <a name="module_cluster_autoscaler_irsa_role"></a> [cluster\_autoscaler\_irsa\_role](#module\_cluster\_autoscaler\_irsa\_role) | git::https://github.com/leanspace/terraform-aws-modules.git//iam/irsa-role | main |
| <a name="module_db_kms_key"></a> [db\_kms\_key](#module\_db\_kms\_key) | git::https://github.com/leanspace/terraform-aws-modules.git//kms | main |
| <a name="module_eks_cluster"></a> [eks\_cluster](#module\_eks\_cluster) | git::https://github.com/leanspace/terraform-aws-modules.git//eks/cluster | main |
| <a name="module_eks_control_plane_logs"></a> [eks\_control\_plane\_logs](#module\_eks\_control\_plane\_logs) | git::https://github.com/leanspace/terraform-aws-modules.git//eks/logs | main |
| <a name="module_eks_managed_node_group"></a> [eks\_managed\_node\_group](#module\_eks\_managed\_node\_group) | git::https://github.com/leanspace/terraform-aws-modules.git//eks/node-group | main |
| <a name="module_install_coredns_addon"></a> [install\_coredns\_addon](#module\_install\_coredns\_addon) | git::https://github.com/leanspace/terraform-aws-modules.git//eks/addons | main |
| <a name="module_install_ebscsi_addon"></a> [install\_ebscsi\_addon](#module\_install\_ebscsi\_addon) | git::https://github.com/leanspace/terraform-aws-modules.git//eks/addons | main |
| <a name="module_opensearch"></a> [opensearch](#module\_opensearch) | git::https://github.com/leanspace/terraform-aws-modules.git//opensearch | main |
| <a name="module_opensearch_kms_key"></a> [opensearch\_kms\_key](#module\_opensearch\_kms\_key) | git::https://github.com/leanspace/terraform-aws-modules.git//kms | main |
| <a name="module_postgres"></a> [postgres](#module\_postgres) | git::https://github.com/leanspace/terraform-aws-modules.git//database | main |
| <a name="module_services_s3_irsa_role"></a> [services\_s3\_irsa\_role](#module\_services\_s3\_irsa\_role) | git::https://github.com/leanspace/terraform-aws-modules.git//iam/irsa-role | main |
| <a name="module_vault_export_acm"></a> [vault\_export\_acm](#module\_vault\_export\_acm) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |
| <a name="module_vault_export_database"></a> [vault\_export\_database](#module\_vault\_export\_database) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |
| <a name="module_vault_export_eks"></a> [vault\_export\_eks](#module\_vault\_export\_eks) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |
| <a name="module_vault_export_networking"></a> [vault\_export\_networking](#module\_vault\_export\_networking) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |
| <a name="module_vault_export_opensearch"></a> [vault\_export\_opensearch](#module\_vault\_export\_opensearch) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |
| <a name="module_vault_export_s3"></a> [vault\_export\_s3](#module\_vault\_export\_s3) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | git::https://github.com/leanspace/terraform-aws-modules.git//networking/vpc | main |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | git::https://github.com/leanspace/terraform-aws-modules.git//networking/vpc-endpoints | main |
| <a name="module_vpc_flow_logs"></a> [vpc\_flow\_logs](#module\_vpc\_flow\_logs) | git::https://github.com/leanspace/terraform-aws-modules.git//networking/vpc-flow-logs | main |
| <a name="module_vpc_lattice"></a> [vpc\_lattice](#module\_vpc\_lattice) | git::https://github.com/leanspace/terraform-aws-modules.git//networking/vpc-lattice | main |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ec2_tag.private_subnet_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.private_subnet_internal_elb](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_cluster](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_elb](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/ec2_tag) | resource |
| [aws_eks_access_entry.admins](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_entry.github_eks_deploy](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.admins](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_access_policy_association.github_eks_deploy](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/eks_access_policy_association) | resource |
| [aws_iam_policy.alb_controller](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.alb_controller](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_role) | resource |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_role) | resource |
| [aws_iam_role.github_eks_deploy](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.github_eks_deploy](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.alb_controller_attach](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.vpc_lattice_allow_all](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/security_group) | resource |
| [aws_security_group_rule.postgres_self_reference](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/resources/security_group_rule) | resource |
| [time_sleep.wait_for_oidc](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_openid_connect_provider.oidc](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/iam_session_context) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/region) | data source |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/route53_zone) | data source |
| [aws_secretsmanager_secret_version.db_master_password](https://registry.terraform.io/providers/hashicorp/aws/5.95.0/docs/data-sources/secretsmanager_secret_version) | data source |
| [http_http.alb_controller_policy](https://registry.terraform.io/providers/hashicorp/http/3.4.5/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alternative_names"></a> [alternative\_names](#input\_alternative\_names) | List of alternative domain names for the certificate | `list(string)` | `[]` | no |
| <a name="input_aurora_engine_version"></a> [aurora\_engine\_version](#input\_aurora\_engine\_version) | Aurora PostgreSQL engine version | `string` | `"14.13"` | no |
| <a name="input_aurora_instances"></a> [aurora\_instances](#input\_aurora\_instances) | Map of Aurora instances | `map(any)` | <pre>{<br/>  "1": {<br/>    "auto_minor_version_upgrade": false,<br/>    "ca_cert_identifier": "rds-ca-ecc384-g1",<br/>    "db_parameter_group_name": "default.aurora-postgresql14",<br/>    "instance_class": "db.t3.medium",<br/>    "performance_insights_enabled": true,<br/>    "publicly_accessible": false<br/>  }<br/>}</pre> | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region to deploy resources in | `string` | n/a | yes |
| <a name="input_azs"></a> [azs](#input\_azs) | A list of availability zones names or ids in the region | `list(string)` | `[]` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS cluster version | `string` | `"1.32"` | no |
| <a name="input_component_category"></a> [component\_category](#input\_component\_category) | The category of the component being deployed | `string` | `"platform-infrastructure"` | no |
| <a name="input_component_name"></a> [component\_name](#input\_component\_name) | Name of the component being deployed (local-backend only) | `string` | `"null"` | no |
| <a name="input_coredns_addon_version"></a> [coredns\_addon\_version](#input\_coredns\_addon\_version) | CoreDNS addon version | `string` | `"v1.11.4-eksbuild.2"` | no |
| <a name="input_data_node_count"></a> [data\_node\_count](#input\_data\_node\_count) | Number of data nodes (Only applicable if mode is CUSTOM) | `number` | `null` | no |
| <a name="input_data_node_type"></a> [data\_node\_type](#input\_data\_node\_type) | Instance type for data nodes (Only applicable if mode is CUSTOM) | `string` | `null` | no |
| <a name="input_deployment_mode"></a> [deployment\_mode](#input\_deployment\_mode) | The mode of deployment for the OpenSearch cluster (PROD, DEV, or CUSTOM). Irrelevant (leave as default) when enable\_opensearch is false. | `string` | `"DEV"` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for the certificate. Required when enable\_acm is true; irrelevant (leave as default) otherwise. | `string` | `""` | no |
| <a name="input_ebs_addon_version"></a> [ebs\_addon\_version](#input\_ebs\_addon\_version) | ebs addon version | `string` | `"v1.43.0-eksbuild.1"` | no |
| <a name="input_eks_admin_principal_arns"></a> [eks\_admin\_principal\_arns](#input\_eks\_admin\_principal\_arns) | Extra IAM principal ARNs granted AmazonEKSClusterAdminPolicy. github-deployment-role is always included from the account ID (no iam:GetRole). SSO admin roles are not auto-discovered. | `list(string)` | `[]` | no |
| <a name="input_eks_pod_identity_agent_addon_version"></a> [eks\_pod\_identity\_agent\_addon\_version](#input\_eks\_pod\_identity\_agent\_addon\_version) | EKS Pod Identity Agent addon version | `string` | n/a | yes |
| <a name="input_enable_acm"></a> [enable\_acm](#input\_enable\_acm) | Whether to create the ACM certificate. | `bool` | `true` | no |
| <a name="input_enable_database"></a> [enable\_database](#input\_enable\_database) | Whether to create the Aurora Postgres database. | `bool` | `true` | no |
| <a name="input_enable_flow_log"></a> [enable\_flow\_log](#input\_enable\_flow\_log) | Whether or not to enable VPC Flow Logs | `bool` | `true` | no |
| <a name="input_enable_github_eks_deploy_role"></a> [enable\_github\_eks\_deploy\_role](#input\_enable\_github\_eks\_deploy\_role) | Create the leanspace-<env>-github-eks-deploy role (GitHub Actions OIDC, eks:DescribeCluster + cluster admin) used by platform-delivery's deploy-to-dev.yml. | `bool` | `false` | no |
| <a name="input_enable_networking"></a> [enable\_networking](#input\_enable\_networking) | Whether to create the networking module's VPC. Set to false (and provide vpc\_id/private\_subnets/public\_subnets) when reusing an existing VPC instead - e.g. during the agnostic migration, where the VPC already exists from a CloudFormation stack and this module's own state has nothing in it. | `bool` | `true` | no |
| <a name="input_enable_opensearch"></a> [enable\_opensearch](#input\_enable\_opensearch) | Whether to create the OpenSearch cluster. | `bool` | `true` | no |
| <a name="input_enable_vault_export"></a> [enable\_vault\_export](#input\_enable\_vault\_export) | Whether components export their important ARNs to Vault | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment for this deployment (e.g., agnostk, develop, prod) | `string` | n/a | yes |
| <a name="input_flow_log_destination_arn"></a> [flow\_log\_destination\_arn](#input\_flow\_log\_destination\_arn) | The ARN of the CloudWatch log group or S3 bucket where VPC Flow Logs will be pushed. If this ARN is a S3 bucket the appropriate permissions need to be set on that bucket's policy. When create\_flow\_log\_cloudwatch\_log\_group is set to false this argument must be provided | `string` | `""` | no |
| <a name="input_flow_log_destination_type"></a> [flow\_log\_destination\_type](#input\_flow\_log\_destination\_type) | Type of flow log destination. Can be s3, kinesis-data-firehose or cloud-watch-logs | `string` | `"s3"` | no |
| <a name="input_github_eks_deploy_subjects"></a> [github\_eks\_deploy\_subjects](#input\_github\_eks\_deploy\_subjects) | GitHub OIDC sub patterns allowed to assume the github-eks-deploy role, e.g. "repo:leanspace/*:ref:refs/heads/main". Required when enable\_github\_eks\_deploy\_role is true. | `list(string)` | `[]` | no |
| <a name="input_high_availability"></a> [high\_availability](#input\_high\_availability) | Enable high availability for the OpenSearch cluster | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true` | `string` | `null` | no |
| <a name="input_kube_proxy_addon_version"></a> [kube\_proxy\_addon\_version](#input\_kube\_proxy\_addon\_version) | Kube Proxy addon version | `string` | n/a | yes |
| <a name="input_master_node_type"></a> [master\_node\_type](#input\_master\_node\_type) | Instance type for master nodes (Only applicable if mode is CUSTOM) | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name to be used on all the networking resources as identifier | `string` | `"leanspace-vpc"` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of EKS managed node groups to create. Keys are node group names. A 'system' pool is required (untainted add-ons + outputs asg\_name/min\_nodes/max\_nodes). | <pre>map(object({<br/>    minimum_node_count  = number<br/>    maximum_node_count  = number<br/>    desired_node_count  = number<br/>    node_instance_types = list(string)<br/>    node_capacity_type  = string<br/>    subnet_ids          = optional(list(string), [])<br/>    extra_labels        = optional(map(string), {})<br/>    taints = optional(list(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string<br/>    })), [])<br/>    # Extra node role policies (key => ARN). null = module default (SSM + standard EKS worker/CNI/ECR).<br/>    iam_role_additional_policies = optional(map(string))<br/>  }))</pre> | n/a | yes |
| <a name="input_node_imds_hop_limit"></a> [node\_imds\_hop\_limit](#input\_node\_imds\_hop\_limit) | IMDSv2 hop limit on all node groups. 1 blocks pods from reaching the node role through IMDS; 2 is the current behaviour. Changing it rolls every node group | `number` | `2` | no |
| <a name="input_node_security_group_tags"></a> [node\_security\_group\_tags](#input\_node\_security\_group\_tags) | Extra node security group tags (null value removes a tag), passed to the cluster module. Use { "kubernetes.io/cluster/<cluster\_name>" = null } so the AWS Load Balancer Controller sees a single cluster-tagged SG per pod ENI. | `map(string)` | `{}` | no |
| <a name="input_opensearch_tls_security_policy"></a> [opensearch\_tls\_security\_policy](#input\_opensearch\_tls\_security\_policy) | TLS security policy for OpenSearch | `string` | `"Policy-Min-TLS-1-2-2019-07"` | no |
| <a name="input_opensearch_version"></a> [opensearch\_version](#input\_opensearch\_version) | Version of OpenSearch to deploy | `string` | `"OpenSearch_2.11"` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Existing private subnet IDs for the EKS control plane and node groups. Required when vpc\_id is set. | `list(string)` | `[]` | no |
| <a name="input_profile"></a> [profile](#input\_profile) | The platform-delivery profile this environment belongs to (e.g. leanspace-aws) | `string` | n/a | yes |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | Existing public subnet IDs to tag for internet-facing load balancers. Optional when vpc\_id is set. | `list(string)` | `[]` | no |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | The prefix for the resources | `string` | `"leanspace"` | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | Retention period for CloudWatch log groups in days | `number` | `90` | no |
| <a name="input_s3_buckets"></a> [s3\_buckets](#input\_s3\_buckets) | Map of S3 buckets to manage, keyed by a short logical name. Several keys<br/>are already known (the buckets the platform uses today, see<br/>local.known\_bucket\_names in s3.tf) and default to disabled; reusing one<br/>of those keys here overrides its fields (most commonly just<br/>`enabled = true`). Any other key creates a brand-new, ad-hoc bucket the<br/>same way. Every bucket, known or ad-hoc, defaults to disabled unless<br/>explicitly enabled.<br/><br/>versioning\_enabled is left unset (null) rather than defaulting here so<br/>that enabling a known bucket (e.g. `{ enabled = true }`) doesn't silently<br/>override that bucket's category-appropriate default from<br/>local.known\_bucket\_overrides in s3.tf -- set it explicitly to override<br/>that default either way. | <pre>map(object({<br/>    enabled            = optional(bool, false)<br/>    name               = optional(string)<br/>    versioning_enabled = optional(bool)<br/>    force_destroy      = optional(bool, false)<br/>    sse_algorithm      = optional(string, "aws:kms")<br/>    kms_key_arn        = optional(string)<br/>    lifecycle_rule     = optional(any, [])<br/>    policy_json        = optional(string)<br/>    tags               = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_services_s3_bucket_names"></a> [services\_s3\_bucket\_names](#input\_services\_s3\_bucket\_names) | S3 bucket names the services/lambda IRSA role (leanspace-<env>-services-s3-access)<br/>is granted read/write on. Bucket names differ per environment/AWS account (e.g.<br/>buckets reused from an existing ECS environment during a migration), so this must<br/>be set explicitly per environment - there is no sensible shared default. Leave as<br/>the default empty list to skip creating the role entirely (e.g. environments that<br/>don't need it yet, or where S3 access is still handled another way). | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Team name tag applied to component resources | `string` | `"silver"` | no |
| <a name="input_tfstate_path"></a> [tfstate\_path](#input\_tfstate\_path) | Path to the local backend terraform state file (local-backend only) | `string` | `"null"` | no |
| <a name="input_via_service"></a> [via\_service](#input\_via\_service) | AWS service that is using the KMS key (e.g., 'rds') | `string` | `"rds"` | no |
| <a name="input_vpc_cni_addon_version"></a> [vpc\_cni\_addon\_version](#input\_vpc\_cni\_addon\_version) | VPC CNI addon version | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID to deploy the EKS cluster into. When set, the networking module's VPC is not used. | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_controller_role_arn"></a> [alb\_controller\_role\_arn](#output\_alb\_controller\_role\_arn) | IRSA role ARN for the AWS Load Balancer Controller. |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Autoscaling group name for the untainted system node group (cluster-autoscaler). |
| <a name="output_asg_names"></a> [asg\_names](#output\_asg\_names) | n/a |
| <a name="output_aurora_db_cluster_identifier"></a> [aurora\_db\_cluster\_identifier](#output\_aurora\_db\_cluster\_identifier) | The identifier of the Aurora DB cluster (null if enable\_database is false). |
| <a name="output_aurora_db_endpoint"></a> [aurora\_db\_endpoint](#output\_aurora\_db\_endpoint) | The endpoint of the Aurora DB cluster (null if enable\_database is false). |
| <a name="output_aurora_db_port"></a> [aurora\_db\_port](#output\_aurora\_db\_port) | The port of the Aurora DB cluster (null if enable\_database is false). |
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Map of logical bucket name to its ARN, for every enabled bucket |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | Map of logical bucket name to its actual S3 bucket name, for every enabled bucket |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the certificate for agnostk.leanspace.io (null if enable\_acm is false) |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | n/a |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_database_cluster_arn"></a> [database\_cluster\_arn](#output\_database\_cluster\_arn) | The ARN of the Aurora DB cluster (null if enable\_database is false). |
| <a name="output_eks_cluster_arn"></a> [eks\_cluster\_arn](#output\_eks\_cluster\_arn) | The ARN of the EKS cluster. |
| <a name="output_flow_log_destination_arn"></a> [flow\_log\_destination\_arn](#output\_flow\_log\_destination\_arn) | The ARN of the VPC flow log destination (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_igw_arn"></a> [igw\_arn](#output\_igw\_arn) | The ARN of the Internet Gateway (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_igw_id"></a> [igw\_id](#output\_igw\_id) | The ID of the Internet Gateway (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_key_aliases"></a> [key\_aliases](#output\_key\_aliases) | List of aliases created for the KMS key (null if enable\_database is false). |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | The Amazon Resource Name (ARN) of the KMS key (null if enable\_database is false). |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | The globally unique identifier for the KMS key (null if enable\_database is false). |
| <a name="output_max_nodes"></a> [max\_nodes](#output\_max\_nodes) | n/a |
| <a name="output_min_nodes"></a> [min\_nodes](#output\_min\_nodes) | n/a |
| <a name="output_nat_ids"></a> [nat\_ids](#output\_nat\_ids) | List of allocation ID of Elastic IPs created for AWS NAT Gateway (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_natgw_ids"></a> [natgw\_ids](#output\_natgw\_ids) | List of NAT Gateway IDs (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | n/a |
| <a name="output_opensearch_arn"></a> [opensearch\_arn](#output\_opensearch\_arn) | ARN of the OpenSearch cluster (null if enable\_opensearch is false) |
| <a name="output_opensearch_endpoint"></a> [opensearch\_endpoint](#output\_opensearch\_endpoint) | Endpoint of the OpenSearch cluster (null if enable\_opensearch is false) |
| <a name="output_opensearch_name"></a> [opensearch\_name](#output\_opensearch\_name) | Name of the OpenSearch cluster (null if enable\_opensearch is false) |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | The ID of the VPC (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_private_subnet_arns"></a> [private\_subnet\_arns](#output\_private\_subnet\_arns) | List of ARNs of private subnets (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of IDs of private subnets - either the ones this root created, or the existing ones passed in via var.private\_subnets when enable\_networking is false. |
| <a name="output_private_subnets_cidr_blocks"></a> [private\_subnets\_cidr\_blocks](#output\_private\_subnets\_cidr\_blocks) | List of cidr\_blocks of private subnets (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_public_route_table_ids"></a> [public\_route\_table\_ids](#output\_public\_route\_table\_ids) | The ID of the VPC (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_public_subnet_arns"></a> [public\_subnet\_arns](#output\_public\_subnet\_arns) | List of ARNs of public subnets (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | List of IDs of public subnets (falls back to var.public\_subnets when enable\_networking is false) |
| <a name="output_public_subnets_cidr_blocks"></a> [public\_subnets\_cidr\_blocks](#output\_public\_subnets\_cidr\_blocks) | List of CIDR blocks of public subnets (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The security group ID of the Aurora DB (null if enable\_database is false). |
| <a name="output_services_s3_irsa_role_arn"></a> [services\_s3\_irsa\_role\_arn](#output\_services\_s3\_irsa\_role\_arn) | IRSA role ARN for services/lambda S3 access (null if services\_s3\_bucket\_names is empty). |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | The ARN of the VPC (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | n/a |
| <a name="output_vpc_flow_log_id"></a> [vpc\_flow\_log\_id](#output\_vpc\_flow\_log\_id) | The ID of the Flow Log resource (null if enable\_networking is false - no equivalent when reusing an existing VPC) |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC - either the one this root created, or the existing one passed in via var.vpc\_id when enable\_networking is false. |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | The name of the VPC specified as argument to this module |
<!-- END_TF_DOCS -->
