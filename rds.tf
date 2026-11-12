locals {
  database_tags = {
    component-category = var.component_category
    component-type     = "database-cluster"
    environment        = var.environment
    managed-by         = "terraform"
    team               = var.team_name
  }

  # platform-infra-modules//aws/database defaults both parameter group family
  # variables to a hardcoded "aurora-postgresql14", independent of
  # aurora_engine_version - breaks the moment aurora_engine_version is anything
  # else (confirmed: AWS rejects a 14-family parameter group against an
  # aurora-postgresql18 cluster). Derive and pass it explicitly instead.
  aurora_parameter_group_family = "aurora-postgresql${split(".", var.aurora_engine_version)[0]}"
  aurora_major_version          = tonumber(split(".", var.aurora_engine_version)[0])

  # Previously database/db-parameter-group.tf
  db_parameter_group_parameters = [
    { name = "shared_preload_libraries", value = "auto_explain,pg_stat_statements,pg_hint_plan,pgaudit", apply_method = "pending-reboot" },
    { name = "log_statement", value = "ddl", apply_method = "pending-reboot" }, # Changed to pending-reboot
    # PostgreSQL 18 changed log_connections from a boolean to an enum list
    # (receipt, authentication, authorization, setup_durations, all) - the old
    # "1" (PG <18's "on") is rejected on 18+. "all" is the closest equivalent.
    { name = "log_connections", value = local.aurora_major_version >= 18 ? "all" : "1", apply_method = "immediate" },
    { name = "log_disconnections", value = 1, apply_method = "immediate" },
    { name = "log_lock_waits", value = 1, apply_method = "immediate" },
    { name = "log_min_duration_statement", value = 5000, apply_method = "immediate" },
    { name = "auto_explain.log_min_duration", value = 5000, apply_method = "immediate" },
    { name = "auto_explain.log_verbose", value = 1, apply_method = "immediate" },
    { name = "log_rotation_age", value = 1440, apply_method = "pending-reboot" },    # Changed to pending-reboot
    { name = "log_rotation_size", value = 102400, apply_method = "pending-reboot" }, # Changed to pending-reboot
    { name = "rds.log_retention_period", value = 10080, apply_method = "immediate" },
    { name = "random_page_cost", value = 1, apply_method = "immediate" },
    { name = "track_activity_query_size", value = 16384, apply_method = "pending-reboot" }, # Changed to pending-reboot
    { name = "idle_in_transaction_session_timeout", value = 7200000, apply_method = "immediate" },
    { name = "statement_timeout", value = 60000, apply_method = "immediate" },
    { name = "search_path", value = "\"$user\",public", apply_method = "immediate" }
  ]
}

# Re-read on every apply (not a one-time snapshot) - AWS's own rotation Lambda
# changes this on its own schedule, and this data source always resolves the
# CURRENT AWSCURRENT version, so routine applies keep Vault's copy from
# drifting too far. Still a point-in-time copy between applies, not a live
# read - nothing here stays in sync between two applies.
data "aws_secretsmanager_secret_version" "db_master_password" {
  count     = var.enable_database ? 1 : 0
  secret_id = module.postgres[0].master_user_secret_arn
}

module "postgres" {
  count                 = var.enable_database ? 1 : 0
  depends_on            = [module.db_kms_key]
  source                = "git::https://github.com/leanspace/terraform-aws-modules.git//database?ref=v0.1.9"
  aurora_name           = "${var.resource_prefix}-${var.environment}-db"
  aurora_engine_version = var.aurora_engine_version
  kms_key_id            = module.db_kms_key[0].key_arn
  aurora_instances      = var.aurora_instances
  deletion_protection   = var.database_deletion_protection
  vpc_id                = local.vpc_id
  db_subnet_group_name  = "${var.resource_prefix}-${var.environment}-db-subnet-group"
  private_subnets       = local.private_subnets
  security_group_rules = {
    ingress_from_services_sg = {
      type                     = "ingress"
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "Access from Services SG"
      cidr_blocks              = null
      source_security_group_id = module.eks_cluster.node_security_group_id
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
  security_group_tags               = local.database_tags
  final_snapshot_identifier         = "${var.resource_prefix}-${var.environment}-db-final-snapshot"
  db_cluster_parameter_group_name   = "${var.resource_prefix}-${var.environment}-cluster-parameter-group"
  db_cluster_parameter_group_family = local.aurora_parameter_group_family
  db_parameter_group_name           = "${var.resource_prefix}-${var.environment}-parameter-group"
  db_parameter_group_family         = local.aurora_parameter_group_family
  db_parameter_group_parameters     = local.db_parameter_group_parameters
  tags                              = local.database_tags
  cloudwatch_log_group_kms_key_id   = module.db_kms_key[0].key_arn
}

resource "aws_security_group_rule" "postgres_self_reference" {
  count                    = var.enable_database ? 1 : 0
  depends_on               = [module.postgres]
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  description              = "Self-referencing rule"
  security_group_id        = module.postgres[0].security_group_id
  source_security_group_id = module.postgres[0].security_group_id
}

module "db_kms_key" {
  count           = var.enable_database ? 1 : 0
  source          = "git::https://github.com/leanspace/terraform-aws-modules.git//kms?ref=v0.1.9"
  kms_description = "KMS key for ${var.resource_prefix}-${var.environment} Aurora PG database cluster."
  kms_policy = templatefile("${path.module}/rds-kms-policy.json.tpl", {
    account_id  = data.aws_caller_identity.current.account_id
    region      = data.aws_region.current.name
    via_service = var.via_service
  })
  kms_aliases = ["${var.resource_prefix}-${var.environment}-db-key"]
  tags        = local.database_tags
}

module "vault_export_database" {
  count  = var.enable_database ? 1 : 0
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_cluster_arn"
      data  = { value = module.postgres[0].cluster_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_kms_key_arn"
      data  = { value = module.db_kms_key[0].key_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_cluster_endpoint"
      data  = { value = module.postgres[0].cluster_endpoint }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/database_password"
      data  = { value = jsondecode(data.aws_secretsmanager_secret_version.db_master_password[0].secret_string).password }
    }
  ] : []
}
