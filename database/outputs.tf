output "aurora_db_cluster_identifier" {
  description = "The identifier of the Aurora DB cluster."
  value       = module.postgres.cluster_id
}

output "cluster_arn" {
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