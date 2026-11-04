data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  networking_tags = {
    component-category = var.component_category
    component-type     = "networking"
    environment        = var.environment
    managed-by         = "terraform"
    team               = var.team_name
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                                      = "1"
    "kubernetes.io/cluster/${var.resource_prefix}-${var.environment}-eks-cluster" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                             = "1"
    "kubernetes.io/cluster/${var.resource_prefix}-${var.environment}-eks-cluster" = "shared"
  }
  private_subnet_tags_per_az = {
    for az in data.aws_availability_zones.available.names :
    az => {
      Name = "private-subnet-${substr(az, -1, 1)}"
      AZ   = az
    }
  }
  public_subnet_tags_per_az = {
    for az in data.aws_availability_zones.available.names :
    az => {
      Name = "public-subnet-${substr(az, -1, 1)}"
      AZ   = az
    }
  }

  # Previously networking/endpoints.tf
  vpc_endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      service_type        = "Gateway"
      route_table_ids     = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
      subnet_ids          = flatten([module.vpc.private_subnets, module.vpc.public_subnets])
      tags                = { Name = "s3-vpc-endpoint" }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
      tags            = { Name = "dynamodb-vpc-endpoint" }
    },
    kinesis = {
      service             = "kinesis-streams"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ecr_api = {
      service             = "ecr.api"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
    cloudwatch = {
      service             = "logs"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
    },
  }
}

module "vpc" {
  source                     = "git::https://github.com/leanspace/platform-infra-modules.git//aws/networking/vpc?ref=main"
  name                       = var.name
  azs                        = local.azs
  private_subnet_tags        = local.private_subnet_tags
  private_subnet_tags_per_az = local.private_subnet_tags_per_az
  public_subnet_tags         = local.public_subnet_tags
  public_subnet_tags_per_az  = local.public_subnet_tags_per_az
  enable_flow_log            = var.enable_flow_log
  flow_log_destination_type  = var.enable_flow_log ? "s3" : null
  flow_log_destination_arn   = var.enable_flow_log ? module.vpc_flow_logs.s3_bucket_arn : null
  tags                       = local.networking_tags
}

module "vpc_flow_logs" {
  source         = "git::https://github.com/leanspace/platform-infra-modules.git//aws/networking/vpc-flow-logs?ref=main"
  s3_bucket_name = "${var.resource_prefix}-vpc-flow-logs-${var.environment}"
  tags           = local.networking_tags
}

module "vpc_endpoints" {
  depends_on     = [module.vpc]
  source         = "git::https://github.com/leanspace/platform-infra-modules.git//aws/networking/vpc-endpoints?ref=main"
  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
  endpoints      = local.vpc_endpoints
  tags           = local.networking_tags
}

module "vpc_lattice" {
  depends_on         = [module.vpc]
  source             = "git::https://github.com/leanspace/platform-infra-modules.git//aws/networking/vpc-lattice?ref=main"
  name               = "${var.resource_prefix}-vpc-lattice-${var.environment}"
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [aws_security_group.vpc_lattice_allow_all.id]
  tags               = local.networking_tags
}

resource "aws_security_group" "vpc_lattice_allow_all" {
  name        = "${var.resource_prefix}-vpc-lattice-allow-all-${var.environment}"
  description = "Allow all inbound and outbound traffic for VPC Lattice"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "Allow all inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.networking_tags
}

module "vault_export_networking" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/networking_vpc_arn"
      data  = { value = module.vpc.vpc_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/networking_igw_arn"
      data  = { value = module.vpc.igw_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/networking_flow_log_destination_arn"
      data  = { value = module.vpc_flow_logs.s3_bucket_arn }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/networking_public_subnet_arns"
      data  = { value = jsonencode(module.vpc.public_subnet_arns) }
    },
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/networking_private_subnet_arns"
      data  = { value = jsonencode(module.vpc.private_subnet_arns) }
    }
  ] : []
}
