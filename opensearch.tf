locals {
  opensearch_name_prefix = "${var.resource_prefix}-${var.environment}"

  opensearch_master_node_type = (
    var.deployment_mode == "PROD" ? "c6g.large.search" :
    var.deployment_mode == "CUSTOM" ? var.master_node_type :
    null
  )
  opensearch_data_node_type = (
    var.deployment_mode == "PROD" ? "m6g.xlarge.search" :
    var.deployment_mode == "DEV" ? "m6g.large.search" :
    var.deployment_mode == "CUSTOM" ? var.data_node_type :
    null
  )
  opensearch_data_node_count = (
    var.deployment_mode == "PROD" ? 3 :
    var.deployment_mode == "DEV" ? 1 :
    var.deployment_mode == "CUSTOM" ? var.data_node_count :
    null
  )

  # Calculate the maximum number of availability zones based on the data node count
  opensearch_instance_count     = local.opensearch_data_node_count
  opensearch_max_subnets        = length(local.private_subnets)
  opensearch_subnet_count       = min(local.opensearch_instance_count, local.opensearch_max_subnets)
  opensearch_cluster_subnet_ids = slice(local.private_subnets, 0, local.opensearch_subnet_count)
  opensearch_tags = {
    component-category = var.component_category
    component-type     = "opensearch-cluster"
    environment        = var.environment
    managed-by         = "terraform"
    team               = var.team_name
  }
}

data "aws_partition" "current" {}

# This block creates kms key for OpenSearch cluster
module "opensearch_kms_key" {
  count  = var.enable_opensearch ? 1 : 0
  source = "git::https://github.com/leanspace/terraform-aws-modules.git//kms?ref=main"

  kms_description = "KMS key for ${var.resource_prefix} ${var.environment} opensearch cluster."
  kms_aliases     = ["${local.opensearch_name_prefix}-opensearch-key-alias"]

  kms_policy = templatefile("${path.module}/opensearch-kms-policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.name
  })

  tags = local.opensearch_tags
}

# This block creates the OpenSearch cluster
module "opensearch" {
  count  = var.enable_opensearch ? 1 : 0
  source = "git::https://github.com/leanspace/terraform-aws-modules.git//opensearch?ref=main"

  vpc_id          = local.vpc_id
  private_subnets = local.opensearch_cluster_subnet_ids

  cluster_name       = "${local.opensearch_name_prefix}-opensearch"
  opensearch_version = var.opensearch_version

  opensearch_tls_security_policy = var.opensearch_tls_security_policy
  opensearch_encryption_key_arn  = module.opensearch_kms_key[0].key_arn

  data_node_count  = local.opensearch_data_node_count
  data_node_type   = local.opensearch_data_node_type
  master_node_type = local.opensearch_master_node_type

  high_availability = var.high_availability

}

module "vault_export_opensearch" {
  count  = var.enable_opensearch ? 1 : 0
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/opensearch_arn"
      data  = { value = module.opensearch[0].arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/opensearch_endpoint"
      data  = { value = module.opensearch[0].endpoint }
    }
  ] : []
}
