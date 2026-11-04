########################################
# acm
########################################

output "certificate_arn" {
  description = "ARN of the certificate for agnostk.leanspace.io (null if enable_acm is false)"
  value       = try(module.agnostk_certificate[0].certificate_arn, null)
}

########################################
# rds (database)
########################################

output "aurora_db_cluster_identifier" {
  description = "The identifier of the Aurora DB cluster (null if enable_database is false)."
  value       = try(module.postgres[0].cluster_id, null)
}

# Renamed from "cluster_arn" (collided with eks's output of the same name
# now that both live in one root).
output "database_cluster_arn" {
  description = "The ARN of the Aurora DB cluster (null if enable_database is false)."
  value       = try(module.postgres[0].cluster_arn, null)
}

output "aurora_db_endpoint" {
  description = "The endpoint of the Aurora DB cluster (null if enable_database is false)."
  value       = try(module.postgres[0].cluster_endpoint, null)
}

output "aurora_db_port" {
  description = "The port of the Aurora DB cluster (null if enable_database is false)."
  value       = try(module.postgres[0].cluster_port, null)
}

output "key_id" {
  description = "The globally unique identifier for the KMS key (null if enable_database is false)."
  value       = try(module.db_kms_key[0].key_id, null)
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key (null if enable_database is false)."
  value       = try(module.db_kms_key[0].key_arn, null)
}

output "key_aliases" {
  description = "List of aliases created for the KMS key (null if enable_database is false)."
  value       = try(module.db_kms_key[0].key_aliases, null)
}

output "security_group_id" {
  description = "The security group ID of the Aurora DB (null if enable_database is false)."
  value       = try(module.postgres[0].security_group_id, null)
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
  description = "The ARN of the EKS cluster."
  value       = module.eks_cluster.cluster_arn
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
  description = "The ID of the VPC - either the one this root created, or the existing one passed in via var.vpc_id when enable_networking is false."
  value       = local.vpc_id
}

output "public_route_table_ids" {
  description = "The ID of the VPC (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].public_route_table_ids, null)
}

output "private_route_table_ids" {
  description = "The ID of the VPC (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].private_route_table_ids, null)
}

output "flow_log_destination_arn" {
  description = "The ARN of the VPC flow log destination (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc_flow_logs[0].s3_bucket_arn, null)
}

output "vpc_arn" {
  description = "The ARN of the VPC (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].vpc_arn, null)
}

output "vpc_cidr_block" {
  value = try(module.vpc[0].vpc_cidr_block, null)
}

output "igw_id" {
  description = "The ID of the Internet Gateway (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].igw_id, null)
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].igw_arn, null)
}

output "public_subnets" {
  description = "List of IDs of public subnets (falls back to var.public_subnets when enable_networking is false)"
  value       = var.enable_networking ? module.vpc[0].public_subnets : var.public_subnets
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].public_subnet_arns, null)
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of public subnets (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].public_subnets_cidr_blocks, null)
}

output "private_subnets" {
  description = "List of IDs of private subnets - either the ones this root created, or the existing ones passed in via var.private_subnets when enable_networking is false."
  value       = local.private_subnets
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].private_subnet_arns, null)
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].private_subnets_cidr_blocks, null)
}

output "nat_ids" {
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].nat_ids, null)
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].natgw_ids, null)
}

output "vpc_flow_log_id" {
  description = "The ID of the Flow Log resource (null if enable_networking is false - no equivalent when reusing an existing VPC)"
  value       = try(module.vpc[0].vpc_flow_log_id, null)
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
  description = "Name of the OpenSearch cluster (null if enable_opensearch is false)"
  value       = try(module.opensearch[0].name, null)
}

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch cluster (null if enable_opensearch is false)"
  value       = try(module.opensearch[0].endpoint, null)
}

output "opensearch_arn" {
  description = "ARN of the OpenSearch cluster (null if enable_opensearch is false)"
  value       = try(module.opensearch[0].arn, null)
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
