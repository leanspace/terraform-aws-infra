output "cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "cluster_arn" {
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
