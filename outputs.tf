########################################
# acm
########################################

output "certificate_arn" {
  description = "ARN of the certificate for agnostk.leanspace.io"
  value       = module.agnostk_certificate.certificate_arn
}

########################################
# rds (database)
########################################

output "aurora_db_cluster_identifier" {
  description = "The identifier of the Aurora DB cluster."
  value       = module.postgres.cluster_id
}

# Renamed from "cluster_arn" (collided with eks's output of the same name
# now that both live in one root).
output "database_cluster_arn" {
  description = "The ARN of the Aurora DB cluster."
  value       = module.postgres.cluster_arn
}

output "aurora_db_endpoint" {
  description = "The endpoint of the Aurora DB cluster."
  value       = module.postgres.cluster_endpoint
}

output "aurora_db_port" {
  description = "The port of the Aurora DB cluster."
  value       = module.postgres.cluster_port
}

output "key_id" {
  description = "The globally unique identifier for the KMS key."
  value       = module.db_kms_key.key_id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key."
  value       = module.db_kms_key.key_arn
}

output "key_aliases" {
  description = "List of aliases created for the KMS key."
  value       = module.db_kms_key.key_aliases
}

output "security_group_id" {
  description = "The security group ID of the Aurora DB."
  value       = module.postgres.security_group_id
}

########################################
# eks
########################################

output "cluster_name" {
  value = module.eks_cluster.cluster_name
}

# Renamed from "cluster_arn" (collided with database's output of the same
# name now that both live in one root).
output "eks_cluster_arn" {
  value = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  value     = module.eks_cluster.cluster_endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  sensitive = true
}

output "asg_name" {
  value       = module.eks_managed_node_group["system"].node_group_autoscaling_group_names[0]
  description = "Autoscaling group name for the untainted system node group (cluster-autoscaler)."
}

output "asg_names" {
  value = {
    for name, ng in module.eks_managed_node_group : name => ng.node_group_autoscaling_group_names[0]
  }
}

output "min_nodes" {
  value = var.node_groups["system"].minimum_node_count
}

output "max_nodes" {
  value = var.node_groups["system"].maximum_node_count
}

output "node_security_group_id" {
  value = module.eks_cluster.node_security_group_id
}

output "alb_controller_role_arn" {
  value       = aws_iam_role.alb_controller.arn
  description = "IRSA role ARN for the AWS Load Balancer Controller."
}

output "services_s3_irsa_role_arn" {
  value       = try(module.services_s3_irsa_role[0].role_arn, null)
  description = "IRSA role ARN for services/lambda S3 access (null if services_s3_bucket_names is empty)."
}

########################################
# networking
########################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_route_table_ids" {
  description = "The ID of the VPC"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "The ID of the VPC"
  value       = module.vpc.private_route_table_ids
}

output "flow_log_destination_arn" {
  description = "The ID of the VPC"
  value       = module.vpc_flow_logs.s3_bucket_arn
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway"
  value       = module.vpc.igw_arn
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = module.vpc.public_subnet_arns
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = module.vpc.private_subnet_arns
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "nat_ids" {
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_ids
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "vpc_flow_log_id" {
  description = "The ID of the Flow Log resource"
  value       = module.vpc.vpc_flow_log_id
}

# Renamed from "name" (collided with opensearch's output of the same name
# now that both live in one root).
output "vpc_name" {
  description = "The name of the VPC specified as argument to this module"
  value       = var.name
}

########################################
# opensearch
########################################

# Renamed from "name" (collided with networking's output of the same name
# now that both live in one root).
output "opensearch_name" {
  description = "Name of the OpenSearch cluster"
  value       = module.opensearch.name
}

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch cluster"
  value       = module.opensearch.endpoint
}

output "opensearch_arn" {
  description = "ARN of the OpenSearch cluster"
  value       = module.opensearch.arn
}

########################################
# s3
########################################

output "bucket_arns" {
  description = "Map of logical bucket name to its ARN, for every enabled bucket"
  value       = { for k, m in module.bucket : k => m.arn }
}

output "bucket_names" {
  description = "Map of logical bucket name to its actual S3 bucket name, for every enabled bucket"
  value       = { for k, m in module.bucket : k => m.id }
}
