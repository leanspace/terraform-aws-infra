output "name" {
  description = "Name of the OpenSearch cluster"
  value       = module.opensearch.name
}

output "endpoint" {
  description = "Endpoint of the OpenSearch cluster"
  value       = module.opensearch.endpoint
}

output "arn" {
  description = "ARN of the OpenSearch cluster"
  value       = module.opensearch.arn
}