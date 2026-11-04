output "bucket_arns" {
  description = "Map of logical bucket name to its ARN, for every enabled bucket"
  value       = { for k, m in module.bucket : k => m.arn }
}

output "bucket_names" {
  description = "Map of logical bucket name to its actual S3 bucket name, for every enabled bucket"
  value       = { for k, m in module.bucket : k => m.id }
}
