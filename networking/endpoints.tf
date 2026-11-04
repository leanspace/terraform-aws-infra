locals {
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