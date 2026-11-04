<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_http"></a> [http](#provider\_http) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_eks_cluster"></a> [eks\_cluster](#module\_eks\_cluster) | git::https://github.com/leanspace/platform-infra-modules.git//aws/eks/cluster | main |
| <a name="module_eks_control_plane_logs"></a> [eks\_control\_plane\_logs](#module\_eks\_control\_plane\_logs) | git::https://github.com/leanspace/platform-infra-modules.git//aws/eks/logs | main |
| <a name="module_eks_managed_node_group"></a> [eks\_managed\_node\_group](#module\_eks\_managed\_node\_group) | git::https://github.com/leanspace/platform-infra-modules.git//aws/eks/node-group | main |
| <a name="module_install_coredns_addon"></a> [install\_coredns\_addon](#module\_install\_coredns\_addon) | git::https://github.com/leanspace/platform-infra-modules.git//aws/eks/addons | main |
| <a name="module_install_ebscsi_addon"></a> [install\_ebscsi\_addon](#module\_install\_ebscsi\_addon) | git::https://github.com/leanspace/platform-infra-modules.git//aws/eks/addons | main |
| <a name="module_services_s3_irsa_role"></a> [services\_s3\_irsa\_role](#module\_services\_s3\_irsa\_role) | git::https://github.com/leanspace/platform-infra-modules.git//aws/iam/irsa-role | main |
| <a name="module_vault_export"></a> [vault\_export](#module\_vault\_export) | git::https://github.com/leanspace/platform-infra-modules.git//vault | main |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ec2_tag.private_subnet_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.private_subnet_internal_elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.public_subnet_elb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_eks_access_entry.admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_iam_policy.alb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.alb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.alb_controller_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [time_sleep.wait_for_oidc](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_openid_connect_provider.oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |
| [http_http.alb_controller_policy](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [terraform_remote_state.networking](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS cluster version | `string` | `"1.32"` | no |
| <a name="input_component_category"></a> [component\_category](#input\_component\_category) | The category of the component being deployed | `string` | `"platform-infrastructure"` | no |
| <a name="input_component_type"></a> [component\_type](#input\_component\_type) | The name of the type of component being deployed | `string` | `"kubernetes-cluster"` | no |
| <a name="input_coredns_addon_version"></a> [coredns\_addon\_version](#input\_coredns\_addon\_version) | CoreDNS addon version | `string` | `"v1.11.4-eksbuild.2"` | no |
| <a name="input_ebs_addon_version"></a> [ebs\_addon\_version](#input\_ebs\_addon\_version) | ebs addon version | `string` | `"v1.43.0-eksbuild.1"` | no |
| <a name="input_eks_admin_principal_arns"></a> [eks\_admin\_principal\_arns](#input\_eks\_admin\_principal\_arns) | Extra IAM principal ARNs granted AmazonEKSClusterAdminPolicy. github-deployment-role is always included from the account ID (no iam:GetRole). SSO admin roles are not auto-discovered. | `list(string)` | `[]` | no |
| <a name="input_eks_pod_identity_agent_addon_version"></a> [eks\_pod\_identity\_agent\_addon\_version](#input\_eks\_pod\_identity\_agent\_addon\_version) | EKS Pod Identity Agent addon version | `string` | n/a | yes |
| <a name="input_kube_proxy_addon_version"></a> [kube\_proxy\_addon\_version](#input\_kube\_proxy\_addon\_version) | Kube Proxy addon version | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of EKS managed node groups to create. Keys are node group names. A 'system' pool is required (untainted add-ons + outputs asg\_name/min\_nodes/max\_nodes). | <pre>map(object({<br/>    minimum_node_count  = number<br/>    maximum_node_count  = number<br/>    desired_node_count  = number<br/>    node_instance_types = list(string)<br/>    node_capacity_type  = string<br/>    extra_labels        = optional(map(string), {})<br/>    taints = optional(list(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string<br/>    })), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_node_security_group_tags"></a> [node\_security\_group\_tags](#input\_node\_security\_group\_tags) | Extra node security group tags (null value removes a tag), passed to the cluster module. Use { "kubernetes.io/cluster/<cluster\_name>" = null } so the AWS Load Balancer Controller sees a single cluster-tagged SG per pod ENI. | `map(string)` | `{}` | no |
| <a name="input_private_subnets"></a> [private\_subnets](#input\_private\_subnets) | Existing private subnet IDs for the EKS control plane and node groups. Required when vpc\_id is set. | `list(string)` | `[]` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | Existing public subnet IDs to tag for internet-facing load balancers. Optional when vpc\_id is set. | `list(string)` | `[]` | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | Retention period for CloudWatch log groups in days | `number` | `90` | no |
| <a name="input_services_s3_bucket_names"></a> [services\_s3\_bucket\_names](#input\_services\_s3\_bucket\_names) | S3 bucket names the services/lambda IRSA role (leanspace-<env>-services-s3-access)<br/>is granted read/write on. Bucket names differ per environment/AWS account (e.g.<br/>buckets reused from an existing ECS environment during a migration), so this must<br/>be set explicitly per environment - there is no sensible shared default. Leave as<br/>the default empty list to skip creating the role entirely (e.g. environments that<br/>don't need it yet, or where S3 access is still handled another way). | `list(string)` | `[]` | no |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Team name tag for the EKS cluster | `string` | n/a | yes |
| <a name="input_vpc_cni_addon_version"></a> [vpc\_cni\_addon\_version](#input\_vpc\_cni\_addon\_version) | VPC CNI addon version | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID to deploy the EKS cluster into. When set, networking remote state is not used. | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_controller_role_arn"></a> [alb\_controller\_role\_arn](#output\_alb\_controller\_role\_arn) | IRSA role ARN for the AWS Load Balancer Controller. |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Autoscaling group name for the untainted system node group (cluster-autoscaler). |
| <a name="output_asg_names"></a> [asg\_names](#output\_asg\_names) | n/a |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | n/a |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | n/a |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_max_nodes"></a> [max\_nodes](#output\_max\_nodes) | n/a |
| <a name="output_min_nodes"></a> [min\_nodes](#output\_min\_nodes) | n/a |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | n/a |
| <a name="output_services_s3_irsa_role_arn"></a> [services\_s3\_irsa\_role\_arn](#output\_services\_s3\_irsa\_role\_arn) | IRSA role ARN for services/lambda S3 access (null if services\_s3\_bucket\_names is empty). |
<!-- END_TF_DOCS -->