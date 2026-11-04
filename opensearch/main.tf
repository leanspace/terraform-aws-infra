# This block defines attributes that would be commonly used across all the modules
locals {
  name_prefix = "${var.resource_prefix}-${var.environment}"

  master_node_type = (
    var.deployment_mode == "PROD" ? "c6g.large.search" :
    var.deployment_mode == "CUSTOM" ? var.master_node_type :
    null
  )
  data_node_type = (
    var.deployment_mode == "PROD" ? "m6g.xlarge.search" :
    var.deployment_mode == "DEV" ? "m6g.large.search" :
    var.deployment_mode == "CUSTOM" ? var.data_node_type :
    null
  )
  data_node_count = (
    var.deployment_mode == "PROD" ? 3 :
    var.deployment_mode == "DEV" ? 1 :
    var.deployment_mode == "CUSTOM" ? var.data_node_count :
    null
  )

  # Calculate the maximum number of availability zones based on the data node count
  instance_count     = local.data_node_count
  max_subnets        = length(data.terraform_remote_state.networking.outputs.private_subnets)
  subnet_count       = min(local.instance_count, local.max_subnets)
  cluster_subnet_ids = slice(data.terraform_remote_state.networking.outputs.private_subnets, 0, local.subnet_count)
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

# This block retrieves the current AWS account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# This block creates kms key for OpenSearch cluster
module "opensearch_kms_key" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//aws/kms?ref=main"

  kms_description = "KMS key for ${var.resource_prefix} ${var.environment} opensearch cluster."
  kms_aliases     = ["${local.name_prefix}-opensearch-key-alias"]

  kms_policy = templatefile("${path.module}/kms_policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.name
  })

  tags = local.common_infra_tags
}

# This block creates the OpenSearch cluster
module "opensearch" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//aws/opensearch?ref=main"

  vpc_id          = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnets = local.cluster_subnet_ids

  cluster_name       = "${local.name_prefix}-opensearch"
  opensearch_version = var.opensearch_version

  opensearch_tls_security_policy = var.opensearch_tls_security_policy
  opensearch_encryption_key_arn  = module.opensearch_kms_key.key_arn

  data_node_count  = local.data_node_count
  data_node_type   = local.data_node_type
  master_node_type = local.master_node_type

  high_availability = var.high_availability

}

module "vault_export" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/opensearch_arn"
      data  = { value = module.opensearch.arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/opensearch_endpoint"
      data  = { value = module.opensearch.endpoint }
    }
  ] : []
}