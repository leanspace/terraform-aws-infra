variable "vpc_id" {
  description = "Existing VPC ID to deploy the EKS cluster into. When set, networking remote state is not used."
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
  description = "Create the leanspace-<env>-github-eks-deploy role (GitHub Actions OIDC, eks:DescribeCluster + cluster admin) used by platform-delivery's deploy-to-dev.yml."
  type        = bool
  default     = false
}

variable "github_eks_deploy_subjects" {
  description = "GitHub OIDC sub patterns allowed to assume the github-eks-deploy role, e.g. \"repo:leanspace/*:ref:refs/heads/main\". Required when enable_github_eks_deploy_role is true."
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

variable "team_name" {
  description = "Team name tag for the EKS cluster"
  type        = string
}

variable "component_category" {
  description = "The category of the component being deployed"
  type        = string
  default     = "platform-infrastructure"
}

variable "component_type" {
  description = "The name of the type of component being deployed"
  type        = string
  default     = "kubernetes-cluster"
}

variable "services_s3_bucket_names" {
  description = <<-EOT
    S3 bucket names the services/lambda IRSA role (leanspace-<env>-services-s3-access)
    is granted read/write on. Bucket names differ per environment/AWS account (e.g.
    buckets reused from an existing ECS environment during a migration), so this must
    be set explicitly per environment - there is no sensible shared default. Leave as
    the default empty list to skip creating the role entirely (e.g. environments that
    don't need it yet, or where S3 access is still handled another way).
  EOT
  type        = list(string)
  default     = []
}

variable "node_security_group_tags" {
  description = "Extra node security group tags (null value removes a tag), passed to the cluster module. Use { \"kubernetes.io/cluster/<cluster_name>\" = null } so the AWS Load Balancer Controller sees a single cluster-tagged SG per pod ENI."
  type        = map(string)
  default     = {}
}
