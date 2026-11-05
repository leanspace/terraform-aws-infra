########################################
# Global (previously shared/variables/global-vars.tf and
# shared/variables/aws/aws-generic-vars.tf, copied in at CI time per
# component; now declared directly since this repo is a single root)
########################################

variable "environment" {
  description = "Environment for this deployment (e.g., agnostk, develop, prod)"
  type        = string
}

variable "profile" {
  description = "The platform-delivery profile this environment belongs to (e.g. leanspace-aws)"
  type        = string
}

variable "enable_vault_export" {
  description = "Whether components export their important ARNs to Vault"
  type        = bool
  default     = true
}

variable "tfstate_path" {
  description = "Path to the local backend terraform state file (local-backend only)"
  type        = string
  default     = "null"
}

variable "component_name" {
  description = "Name of the component being deployed (local-backend only)"
  type        = string
  default     = "null"
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "resource_prefix" {
  description = "The prefix for the resources"
  type        = string
  default     = "leanspace"
}

########################################
# Shared across components (previously declared identically in each
# component's own variables.tf)
########################################

variable "team_name" {
  description = "Team name tag applied to component resources"
  type        = string
  default     = "silver"
}

variable "component_category" {
  description = "The category of the component being deployed"
  type        = string
  default     = "platform-infrastructure"
}

variable "enable_networking" {
  description = "Whether to create the networking module's VPC. Set to false (and provide vpc_id/private_subnets/public_subnets) when reusing an existing VPC instead - e.g. during the agnostic migration, where the VPC already exists from a CloudFormation stack and this module's own state has nothing in it."
  type        = bool
  default     = true

  validation {
    condition     = var.enable_networking || var.vpc_id != ""
    error_message = "enable_networking is false but no vpc_id was provided - nothing would create the VPC eks/rds/opensearch need."
  }
}

variable "enable_acm" {
  description = "Whether to create the ACM certificate."
  type        = bool
  default     = true

  validation {
    condition     = !var.enable_acm || var.domain_name != ""
    error_message = "enable_acm is true but no domain_name was provided."
  }
}

variable "enable_database" {
  description = "Whether to create the Aurora Postgres database."
  type        = bool
  default     = true
}

variable "enable_opensearch" {
  description = "Whether to create the OpenSearch cluster."
  type        = bool
  default     = true
}

########################################
# acm
########################################

variable "domain_name" {
  description = "Domain name for the certificate. Required when enable_acm is true; irrelevant (leave as default) otherwise."
  type        = string
  default     = ""
}

variable "alternative_names" {
  description = "List of alternative domain names for the certificate"
  type        = list(string)
  default     = []
}

########################################
# rds (database)
########################################

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "14.13"
}

variable "aurora_instances" {
  description = "Map of Aurora instances"
  type        = map(any)
  default = {
    1 = {
      instance_class               = "db.t3.medium"
      publicly_accessible          = false
      db_parameter_group_name      = "default.aurora-postgresql14"
      ca_cert_identifier           = "rds-ca-ecc384-g1"
      auto_minor_version_upgrade   = false
      performance_insights_enabled = true
    }
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true`"
  type        = string
  default     = null
}

variable "via_service" {
  description = "AWS service that is using the KMS key (e.g., 'rds')"
  type        = string
  default     = "rds"
}

variable "database_deletion_protection" {
  description = "RDS deletion protection on the Aurora cluster. Defaults to true (the underlying module's own safe default) - set to false only for throwaway test environments. A real apply blocked on \"Cannot delete protected Cluster\" during a terraform destroy means this needs to be false there, or deletion protection needs disabling directly via the AWS CLI/console first."
  type        = bool
  default     = true
}

########################################
# eks
########################################

variable "vpc_id" {
  description = "Existing VPC ID to deploy the EKS cluster into. When set, the networking module's VPC is not used."
  type        = string
  default     = ""
}

variable "private_subnets" {
  description = "Existing private subnet IDs for the EKS control plane and node groups. Required when vpc_id is set."
  type        = list(string)
  default     = []

  validation {
    condition     = var.vpc_id == "" || length(var.private_subnets) > 0
    error_message = "private_subnets must be set when vpc_id is provided."
  }
}

variable "public_subnets" {
  description = "Existing public subnet IDs to tag for internet-facing load balancers. Optional when vpc_id is set."
  type        = list(string)
  default     = []
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.32"
}

variable "kube_proxy_addon_version" {
  description = "Kube Proxy addon version"
  type        = string
}

variable "vpc_cni_addon_version" {
  description = "VPC CNI addon version"
  type        = string
}

variable "coredns_addon_version" {
  description = "CoreDNS addon version"
  type        = string
  default     = "v1.11.4-eksbuild.2"
}

variable "ebs_addon_version" {
  description = "ebs addon version"
  type        = string
  default     = "v1.43.0-eksbuild.1"
}

variable "eks_pod_identity_agent_addon_version" {
  description = "EKS Pod Identity Agent addon version"
  type        = string
}

variable "eks_admin_principal_arns" {
  description = "Extra IAM principal ARNs granted AmazonEKSClusterAdminPolicy. github-deployment-role is always included from the account ID (no iam:GetRole). SSO admin roles are not auto-discovered."
  type        = list(string)
  default     = []
}

variable "enable_github_eks_deploy_role" {
  description = "Create the `leanspace-<env>-github-eks-deploy` role (GitHub Actions OIDC, eks:DescribeCluster + cluster admin) used by platform-delivery's deploy-to-dev.yml."
  type        = bool
  default     = false
}

variable "github_eks_deploy_subjects" {
  description = "GitHub OIDC sub patterns allowed to assume the github-eks-deploy role, e.g. \"repo:leanspace/*:ref:refs/heads/main\". Required when enable_github_eks_deploy_role is true."
  type        = list(string)
  default     = []
}

variable "enable_github_deployment_role" {
  description = "Whether to create github-deployment-role: account-wide AdministratorAccess via GitHub Actions OIDC, restricted to github_deployment_role_subjects (required when true - see its own validation). This role (and the GitHub OIDC provider it and github-eks-deploy both share) previously came from this account's own bootstrap process outside this repo - not present in a freshly-created account until created here. Defaults to false, same as enable_github_eks_deploy_role, since every existing environment's tfvars predates this variable and doesn't set github_deployment_role_subjects."
  type        = bool
  default     = false
}

variable "github_deployment_role_subjects" {
  description = "GitHub OIDC sub patterns allowed to assume github-deployment-role, e.g. \"repo:leanspace/platform-delivery:ref:refs/heads/main\". Required when enable_github_deployment_role is true."
  type        = list(string)
  default     = []
}

variable "node_groups" {
  description = "Map of EKS managed node groups to create. Keys are node group names. A 'system' pool is required (untainted add-ons + outputs asg_name/min_nodes/max_nodes)."
  type = map(object({
    minimum_node_count  = number
    maximum_node_count  = number
    desired_node_count  = number
    node_instance_types = list(string)
    node_capacity_type  = string
    subnet_ids          = optional(list(string), [])
    extra_labels        = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    # Extra node role policies (key => ARN). null = module default (SSM + standard EKS worker/CNI/ECR).
    iam_role_additional_policies = optional(map(string))
  }))
}

variable "node_imds_hop_limit" {
  description = "IMDSv2 hop limit on all node groups. 1 blocks pods from reaching the node role through IMDS; 2 is the current behaviour. Changing it rolls every node group"
  type        = number
  default     = 2
}

variable "retention_in_days" {
  description = "Retention period for CloudWatch log groups in days"
  type        = number
  default     = 90
}

variable "services_s3_bucket_names" {
  description = <<-EOT
    S3 bucket names the services/lambda IRSA role (`leanspace-<env>-services-s3-access`)
    is granted read/write on. Bucket names differ per environment/AWS account (e.g.
    buckets reused from an existing ECS environment during a migration), so this must
    be set explicitly per environment - there is no sensible shared default. Leave as
    the default empty list to skip creating the role entirely (e.g. environments that
    don't need it yet, or where S3 access is still handled another way).
  EOT
  type        = list(string)
  default     = []
}

variable "enable_github_deployment_role_admin_access" {
  description = "Whether to grant `arn:aws:iam::<account_id>:role/github-deployment-role` EKS cluster-admin access. That role comes from this account's own bootstrap process (outside this repo) and may not exist in a freshly-created account - set to false there instead of letting the access entry fail on a nonexistent principal."
  type        = bool
  default     = true
}

variable "node_security_group_tags" {
  description = "Extra node security group tags (null value removes a tag), passed to the cluster module. Use `{ \"kubernetes.io/cluster/<cluster_name>\" = null }` so the AWS Load Balancer Controller sees a single cluster-tagged SG per pod ENI."
  type        = map(string)
  default     = {}
}

########################################
# networking
########################################

variable "name" {
  description = "Name to be used on all the networking resources as identifier"
  type        = string
  default     = "leanspace-vpc"
}

variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = []
}

variable "enable_flow_log" {
  description = "Whether or not to enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_log_destination_type" {
  description = "Type of flow log destination. Can be s3, kinesis-data-firehose or cloud-watch-logs"
  type        = string
  default     = "s3"
}

variable "flow_log_destination_arn" {
  description = "The ARN of the CloudWatch log group or S3 bucket where VPC Flow Logs will be pushed. If this ARN is a S3 bucket the appropriate permissions need to be set on that bucket's policy. When create_flow_log_cloudwatch_log_group is set to false this argument must be provided"
  type        = string
  default     = ""
}

########################################
# opensearch
########################################

variable "deployment_mode" {
  description = "The mode of deployment for the OpenSearch cluster (PROD, DEV, or CUSTOM). Irrelevant (leave as default) when enable_opensearch is false."
  type        = string
  default     = "DEV"
  validation {
    condition     = contains(["PROD", "DEV", "CUSTOM"], var.deployment_mode)
    error_message = "The mode must be either 'PROD', 'DEV', or 'CUSTOM'."
  }
}

variable "high_availability" {
  description = "Enable high availability for the OpenSearch cluster"
  type        = bool
  default     = false
  validation {
    condition     = var.deployment_mode == "PROD" ? var.high_availability == true : true
    error_message = "high_availability must be true when deployment_mode is PROD."
  }
  validation {
    condition     = var.master_node_type != null ? var.high_availability == true : true
    error_message = "high_availability must be true when master_node_type is specified."
  }
}

variable "opensearch_version" {
  description = "Version of OpenSearch to deploy"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_tls_security_policy" {
  description = "TLS security policy for OpenSearch"
  type        = string
  default     = "Policy-Min-TLS-1-2-2019-07"
}

variable "data_node_count" {
  description = "Number of data nodes (Only applicable if mode is CUSTOM)"
  type        = number
  default     = null
  validation {
    condition     = var.deployment_mode == "CUSTOM" ? var.data_node_count != null : true
    error_message = "data_node_count must be specified when deployment_mode is CUSTOM."
  }
}

variable "data_node_type" {
  description = "Instance type for data nodes (Only applicable if mode is CUSTOM)"
  type        = string
  default     = null
  validation {
    condition     = var.deployment_mode == "CUSTOM" ? var.data_node_type != null : true
    error_message = "data_node_type must be specified when deployment_mode is CUSTOM."
  }
}

variable "master_node_type" {
  description = "Instance type for master nodes (Only applicable if mode is CUSTOM)"
  type        = string
  default     = null
  validation {
    condition     = var.deployment_mode == "CUSTOM" ? var.master_node_type != null : true
    error_message = "master_node_type must be specified when deployment_mode is CUSTOM."
  }
}

########################################
# s3
########################################

variable "s3_buckets" {
  description = <<-EOT
    Map of S3 buckets to manage, keyed by a short logical name. Several keys
    are already known (the buckets the platform uses today, see
    local.known_bucket_names in s3.tf) and default to disabled; reusing one
    of those keys here overrides its fields (most commonly just
    `enabled = true`). Any other key creates a brand-new, ad-hoc bucket the
    same way. Every bucket, known or ad-hoc, defaults to disabled unless
    explicitly enabled.

    versioning_enabled is left unset (null) rather than defaulting here so
    that enabling a known bucket (e.g. `{ enabled = true }`) doesn't silently
    override that bucket's category-appropriate default from
    local.known_bucket_overrides in s3.tf -- set it explicitly to override
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
