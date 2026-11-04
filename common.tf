# Shared across multiple components below - declared once here instead of
# once per component now that acm/database/eks/networking/opensearch/s3 all
# live in a single root (and therefore a single state) instead of each being
# applied separately with its own copy of these data sources.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # True when an existing VPC is being reused instead of creating one via
  # networking.tf - e.g. during the agnostic migration, where the VPC
  # already exists from a CloudFormation stack and networking.tf's own
  # Terraform state has nothing in it. eks, rds, and opensearch all resolve
  # their VPC/subnet inputs through these locals instead of reading
  # module.vpc directly, so they work the same way whether networking.tf
  # created the VPC or not.
  use_existing_vpc = var.vpc_id != ""
  vpc_id           = local.use_existing_vpc ? var.vpc_id : module.vpc[0].vpc_id
  private_subnets  = local.use_existing_vpc ? var.private_subnets : module.vpc[0].private_subnets
}
