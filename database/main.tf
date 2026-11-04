# This block defines attributes that would be commonly used across all the modules
locals {
  common_infra_tags = {
    component-category = var.component_category
    component-type     = var.component_type
    environment        = var.environment
    managed-by         = "terraform"
    team               = var.team_name
  }
}

# This block extracts information from the remote state of the networking module
data "terraform_remote_state" "networking" {
  backend = "http"
  config = {
    address                = "https://backend.vault.leanspace.io/v1/state/aws/${var.environment}/core/networking"
    lock_address           = "https://backend.vault.leanspace.io/v1/state/aws/${var.environment}/core/networking"
    unlock_address         = "https://backend.vault.leanspace.io/v1/state/aws/${var.environment}/core/networking"
    lock_method            = "POST"
    unlock_method          = "DELETE"
    skip_cert_verification = true
  }
}

data "terraform_remote_state" "kube-cluster" {
  backend = "http"
  config = {
    address                = "https://backend.vault.leanspace.io/v1/state/aws/${var.environment}/platform/kube-cluster"
    lock_address           = "https://backend.vault.leanspace.io/v1/state/aws/${var.environment}/platform/kube-cluster"
    unlock_address         = "https://backend.vault.leanspace.io/v1/state/aws/${var.environment}/platform/kube-cluster"
    lock_method            = "POST"
    unlock_method          = "DELETE"
    skip_cert_verification = true
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Re-read on every apply (not a one-time snapshot) - AWS's own rotation Lambda
# changes this on its own schedule, and this data source always resolves the
# CURRENT AWSCURRENT version, so routine applies keep Vault's copy from
# drifting too far. Still a point-in-time copy between applies, not a live
# read - nothing here stays in sync between two applies.
data "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = module.postgres.master_user_secret_arn
}

module "postgres" {
  depends_on = [module.db_kms_key]
  source                = "git::https://github.com/leanspace/platform-infra-modules.git//aws/database?ref=main"
  aurora_name           = "${var.resource_prefix}-${var.environment}-db"
  aurora_engine_version = var.aurora_engine_version
  kms_key_id            = module.db_kms_key.key_arn
  aurora_instances      = var.aurora_instances
  vpc_id                = data.terraform_remote_state.networking.outputs.vpc_id
  db_subnet_group_name  = "${var.resource_prefix}-${var.environment}-db-subnet-group"
  private_subnets       = data.terraform_remote_state.networking.outputs.private_subnets
  security_group_rules = {
    ingress_from_services_sg = {
      type                     = "ingress"
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "Access from Services SG"
      cidr_blocks              = null
      source_security_group_id = data.terraform_remote_state.kube-cluster.outputs.node_security_group_id
    }
    egress_example = {
      type                     = "egress"
      from_port                = 0
      to_port                  = 0
      protocol                 = "-1"
      description              = "Egress to corporate printer closet"
      cidr_blocks              = ["0.0.0.0/0"]
      source_security_group_id = null
    }
  }
  security_group_tags             = local.common_infra_tags
  final_snapshot_identifier       = "${var.resource_prefix}-${var.environment}-db-final-snapshot"
  db_cluster_parameter_group_name = "${var.resource_prefix}-${var.environment}-cluster-parameter-group"
  db_parameter_group_name         = "${var.resource_prefix}-${var.environment}-parameter-group"
  db_parameter_group_parameters   = local.db_parameter_group_parameters
  tags                            = local.common_infra_tags
  cloudwatch_log_group_kms_key_id = module.db_kms_key.key_arn
}

resource "aws_security_group_rule" "postgres_self_reference" {
  depends_on               = [module.postgres]
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  description              = "Self-referencing rule"
  security_group_id        = module.postgres.security_group_id
  source_security_group_id = module.postgres.security_group_id
}

module "db_kms_key" {
  source          = "git::https://github.com/leanspace/platform-infra-modules.git//aws/kms?ref=main"
  kms_description = "KMS key for ${var.resource_prefix}-${var.environment} Aurora PG database cluster."
  kms_policy = templatefile("${path.module}/kms_policy.json.tpl", {
    account_id  = data.aws_caller_identity.current.account_id
    region      = data.aws_region.current.name
    via_service = var.via_service
  })
  kms_aliases = ["${var.resource_prefix}-${var.environment}-db-key"]
  tags        = local.common_infra_tags
}

module "vault_export" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_cluster_arn"
      data  = { value = module.postgres.cluster_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_kms_key_arn"
      data  = { value = module.db_kms_key.key_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_cluster_endpoint"
      data  = { value = module.postgres.cluster_endpoint }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_password"
      data  = { value = jsondecode(data.aws_secretsmanager_secret_version.db_master_password.secret_string).password }
    }
  ] : []
}