locals {
  eks_tags = {
    component-category = var.component_category
    component-type     = "kubernetes-cluster"
    environment        = var.environment
    managed-by         = "terraform"
    team               = var.team_name
  }

  cluster_name = "${var.resource_prefix}-${var.environment}-eks-cluster"

  github_deployment_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-deployment-role"

  # No "exclude the current caller" filter here: that was only ever needed to avoid
  # colliding with the eks/cluster module's own dynamic "cluster_creator" access entry,
  # which granted admin to whoever's session ran apply. That's disabled now
  # (enable_cluster_creator_admin_permissions = false in terraform-aws-modules//eks/cluster),
  # so this list is static/config-driven - it must NOT depend on who's currently running
  # terraform, or CI (github-deployment-role) would destroy its own admin access entry
  # every time it applies.
  extra_admin_role_arns = toset(concat(
    var.enable_github_deployment_role_admin_access ? [local.github_deployment_role_arn] : [],
    var.eks_admin_principal_arns
  ))
}

# Tag existing subnets so AWS Load Balancer Controller can discover them.
# aws_ec2_tag adds keys without taking ownership of the CloudFormation subnets.
resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each    = local.use_existing_vpc ? toset(local.private_subnets) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_cluster" {
  for_each    = local.use_existing_vpc ? toset(local.private_subnets) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each    = local.use_existing_vpc ? toset(var.public_subnets) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_subnet_cluster" {
  for_each    = local.use_existing_vpc ? toset(var.public_subnets) : toset([])
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

module "eks_control_plane_logs" {
  source       = "git::https://github.com/leanspace/terraform-aws-modules.git//eks/logs?ref=v0.1.9"
  cluster_name = local.cluster_name
  tags         = local.eks_tags
}

module "eks_cluster" {
  source     = "git::https://github.com/leanspace/terraform-aws-modules.git//eks/cluster?ref=v0.1.9"
  depends_on = [module.eks_control_plane_logs]

  kube_proxy_addon_version             = var.kube_proxy_addon_version
  vpc_cni_addon_version                = var.vpc_cni_addon_version
  eks_pod_identity_agent_addon_version = var.eks_pod_identity_agent_addon_version

  vpc_id          = local.vpc_id
  private_subnets = local.private_subnets

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  node_security_group_tags = var.node_security_group_tags

  tags = local.eks_tags
}

resource "time_sleep" "wait_for_oidc" {
  depends_on      = [module.eks_cluster]
  create_duration = "30s"
}

data "aws_eks_cluster" "this" {
  name       = module.eks_cluster.cluster_name
  depends_on = [time_sleep.wait_for_oidc]
}

data "aws_iam_openid_connect_provider" "oidc" {
  url        = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  depends_on = [time_sleep.wait_for_oidc]
}

module "eks_managed_node_group" {
  source   = "git::https://github.com/leanspace/terraform-aws-modules.git//eks/node-group?ref=v0.1.9"
  for_each = var.node_groups

  # No depends_on = [module.eks_cluster]: the cluster outputs below already order it. An explicit
  # module depends_on defers the node group's data sources whenever the cluster module has any
  # pending change, which forces its IAM policy attachments to be replaced - and the upstream node
  # group's create_before_destroy makes that replace end in a DetachRolePolicy (outage on agnostk).

  cluster_name                      = local.cluster_name
  cluster_version                   = var.cluster_version
  cluster_service_cidr              = module.eks_cluster.cluster_service_cidr
  private_subnets                   = length(each.value.subnet_ids) > 0 ? each.value.subnet_ids : local.private_subnets
  cluster_primary_security_group_id = module.eks_cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_cluster.node_security_group_id]

  node_group_name         = each.key
  minimum_node_count      = each.value.minimum_node_count
  maximum_node_count      = each.value.maximum_node_count
  desired_node_count      = each.value.desired_node_count
  node_instance_types     = each.value.node_instance_types
  node_capacity_type      = each.value.node_capacity_type
  extra_node_group_labels = each.value.extra_labels
  node_group_taints       = each.value.taints

  # null -> module default (SSM + the standard EKS worker/CNI/ECR policies).
  iam_role_additional_policies         = each.value.iam_role_additional_policies
  metadata_http_put_response_hop_limit = var.node_imds_hop_limit

  environment = var.environment
  tags        = local.eks_tags
}

module "install_coredns_addon" {
  source        = "git::https://github.com/leanspace/terraform-aws-modules.git//eks/addons?ref=v0.1.9"
  depends_on    = [module.eks_managed_node_group]
  addon_name    = "coredns"
  addon_version = var.coredns_addon_version
  cluster_name  = local.cluster_name
  tags          = local.eks_tags
}

module "install_ebscsi_addon" {
  source        = "git::https://github.com/leanspace/terraform-aws-modules.git//eks/addons?ref=v0.1.9"
  depends_on    = [module.eks_managed_node_group]
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.ebs_addon_version
  cluster_name  = local.cluster_name
  tags          = local.eks_tags

  service_account_role_arn = aws_iam_role.ebs_csi.arn
}

# EBS CSI controller gets its own IRSA role instead of borrowing the node role.
resource "aws_iam_role" "ebs_csi" {
  name = "leanspace-${var.environment}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(data.aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = local.eks_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# cluster-autoscaler (platform-enablers chart, kube-system/cluster-autoscaler) only manages the
# system node group's ASG (--nodes=min:max:<system asg>), so scaling actions are scoped to it.
module "cluster_autoscaler_irsa_role" {
  source = "git::https://github.com/leanspace/terraform-aws-modules.git//iam/irsa-role?ref=v0.1.9"

  role_name   = "leanspace-${var.environment}-cluster-autoscaler"
  policy_name = "leanspace-${var.environment}-cluster-autoscaler-policy"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${module.eks_managed_node_group["system"].node_group_autoscaling_group_names[0]}"
      },
    ]
  })

  oidc_provider_arn        = data.aws_iam_openid_connect_provider.oidc.arn
  oidc_provider_url        = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  service_account_subjects = ["system:serviceaccount:kube-system:cluster-autoscaler"]

  tags = local.eks_tags
}

resource "aws_iam_policy" "alb_controller" {
  name   = "leanspace-${var.environment}-alb-controller-policy"
  policy = data.http.alb_controller_policy.response_body
}

resource "aws_iam_role" "alb_controller" {
  name = "leanspace-${var.environment}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.oidc.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(data.aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "aws_eks_access_entry" "admins" {
  for_each      = local.extra_admin_role_arns
  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = local.extra_admin_role_arns
  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}

# Role assumed by platform-delivery's deploy-to-dev.yml (called from service repos via
# workflow_call, so the OIDC sub is the *caller* repo). Unlike the account-wide
# github-deployment-role (AdministratorAccess, fixed repo list - see iam.tf), it can
# only describe this cluster and is admin inside it. Created only when
# enable_github_eks_deploy_role. Shares iam.tf's aws_iam_openid_connect_provider.github
# (AWS allows only one OIDC provider per URL per account).
resource "aws_iam_role" "github_eks_deploy" {
  count = var.enable_github_eks_deploy_role ? 1 : 0
  name  = "leanspace-${var.environment}-github-eks-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_eks_deploy_subjects
          }
        }
      }
    ]
  })

  tags = local.eks_tags

  lifecycle {
    precondition {
      condition     = length(var.github_eks_deploy_subjects) > 0
      error_message = "github_eks_deploy_subjects must list at least one OIDC subject when enable_github_eks_deploy_role is true."
    }
  }
}

resource "aws_iam_role_policy" "github_eks_deploy" {
  count = var.enable_github_eks_deploy_role ? 1 : 0
  name  = "describe-cluster"
  role  = aws_iam_role.github_eks_deploy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = module.eks_cluster.cluster_arn
      }
    ]
  })
}

resource "aws_eks_access_entry" "github_eks_deploy" {
  count         = var.enable_github_eks_deploy_role ? 1 : 0
  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = aws_iam_role.github_eks_deploy[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_eks_deploy" {
  count         = var.enable_github_eks_deploy_role ? 1 : 0
  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = aws_iam_role.github_eks_deploy[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_eks_deploy]
}

# IRSA role for streams/plugins/files/records/routes and the streams-packet-decoder
# lambda, replacing the static-key aws-s3-credentials IAM user. Bucket names are
# env-specific (see variables.tf / environment-tfvars) - e.g. on agnostk they're
# buckets reused from the ECS ("testdevelop") environment during the migration.
# Does not touch the separate monitoring-s3 user/policy.
locals {
  services_s3_access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListServicesBuckets"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          for b in var.services_s3_bucket_names : "arn:aws:s3:::${b}"
        ]
      },
      {
        Sid    = "ReadWriteServicesObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
        ]
        Resource = [
          for b in var.services_s3_bucket_names : "arn:aws:s3:::${b}/*"
        ]
      },
      {
        Sid      = "PutSqsPayloadObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::*-s3-for-sqs/*"]
      },
      {
        Sid    = "SQSManagement"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:TagQueue",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:DeleteQueue",
        ]
        Resource = [
          "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*-command-bus.fifo"
        ]
      },
    ]
  })
}

module "services_s3_irsa_role" {
  count = length(var.services_s3_bucket_names) > 0 ? 1 : 0

  source = "git::https://github.com/leanspace/terraform-aws-modules.git//iam/irsa-role?ref=v0.1.9"

  role_name   = "leanspace-${var.environment}-services-s3-access"
  policy_name = "leanspace-${var.environment}-services-s3-access"
  policy_json = local.services_s3_access_policy

  oidc_provider_arn = data.aws_iam_openid_connect_provider.oidc.arn
  oidc_provider_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  # Namespace-scoped wildcards (see platform-infra-modules' irsa-role module): any
  # ServiceAccount in these namespaces can opt in by annotating itself with this
  # role's ARN - no Terraform change needed when a new service needs S3 access.
  service_account_subjects = [
    "system:serviceaccount:services:*",
    "system:serviceaccount:lambda:*",
  ]

  tags = local.eks_tags
}

# Commands offloads SQS command-bus payloads here; expiry must stay above the 23h queue retention.
locals {
  s3_for_sqs_buckets = { for t in var.s3_for_sqs_tenant_keys : t => "${var.environment}-${t}-s3-for-sqs" }

  # Bucket ARN per tenant, regardless of whether this root created it or it already
  # existed (e.g. from CloudFormation - during the agnostic migration this bucket
  # already exists, same pattern as s3_kafka_bridge_queues_exist). Only
  # aws_iam_policy.agent_s3_for_sqs needs the ARN, so only the bucket resource itself
  # needs the toggle.
  s3_for_sqs_bucket_arns = var.s3_for_sqs_bucket_exists ? {
    for k, b in data.aws_s3_bucket.s3_for_sqs_existing : k => b.arn
    } : {
    for k, m in module.s3_for_sqs_bucket : k => m.arn
  }
}

data "aws_s3_bucket" "s3_for_sqs_existing" {
  for_each = var.s3_for_sqs_bucket_exists ? local.s3_for_sqs_buckets : {}
  bucket   = each.value
}

module "s3_for_sqs_bucket" {
  source   = "git::https://github.com/leanspace/terraform-aws-modules.git//s3/bucket?ref=v0.1.9"
  for_each = var.s3_for_sqs_bucket_exists ? {} : local.s3_for_sqs_buckets

  bucket_name        = each.value
  versioning_enabled = false
  sse_algorithm      = "AES256"
  lifecycle_rule = [
    {
      id         = "DeleteOldMessages"
      enabled    = true
      expiration = { days = 1 }
    },
  ]
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = { AWS = "*" }
        Action    = "*"
        Resource  = "arn:aws:s3:::${each.value}/*"
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })

  tags = local.eks_tags
}

# Separate managed policy, so the tenant's CloudFormation stack doesn't remove it from the agent role.
resource "aws_iam_policy" "agent_s3_for_sqs" {
  for_each = local.s3_for_sqs_buckets

  name = "${each.key}-agent-${var.environment}-s3-for-sqs-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AgentS3BucketForSqs"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject",
        ]
        Resource = [
          local.s3_for_sqs_bucket_arns[each.key],
          "${local.s3_for_sqs_bucket_arns[each.key]}/*",
        ]
      },
    ]
  })

  tags = local.eks_tags
}

resource "aws_iam_role_policy_attachment" "agent_s3_for_sqs" {
  for_each = local.s3_for_sqs_buckets

  role       = "${each.key}-agent-aws-credentials-role"
  policy_arn = aws_iam_policy.agent_s3_for_sqs[each.key].arn
}

locals {
  eks_vault_exports = concat(
    [
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_cluster_arn"
        data  = { value = module.eks_cluster.cluster_arn }
      },
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_alb_controller_role_arn"
        data  = { value = aws_iam_role.alb_controller.arn }
      },
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_cluster_autoscaler_role_arn"
        data  = { value = module.cluster_autoscaler_irsa_role.role_arn }
      },
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_asg_name"
        data  = { value = module.eks_managed_node_group["system"].node_group_autoscaling_group_names[0] }
      },
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_asg_min_size"
        data  = { value = tostring(var.node_groups["system"].minimum_node_count) }
      },
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_asg_max_size"
        data  = { value = tostring(var.node_groups["system"].maximum_node_count) }
      },
    ],
    length(module.services_s3_irsa_role) > 0 ? [
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/eks_services_s3_irsa_role_arn"
        data  = { value = module.services_s3_irsa_role[0].role_arn }
      },
      {
        mount = "leanspace"
        path  = "${var.profile}/${var.environment}/object_store_url"
        data  = { value = "https://s3.${data.aws_region.current.name}.amazonaws.com" }
      }
    ] : []
  )
}

module "vault_export_eks" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? local.eks_vault_exports : []
}
