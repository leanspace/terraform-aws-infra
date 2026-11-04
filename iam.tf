# Shared GitHub Actions OIDC provider. AWS allows only one provider per URL per
# account, and both github-deployment-role (below) and eks.tf's narrower
# github-eks-deploy role assume through it - so it's created here, once, whenever
# either feature needs it, instead of each assuming it already exists elsewhere.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_deployment_role || var.enable_github_eks_deploy_role ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Account-wide CI/CD deploy role: AdministratorAccess, restricted to a fixed list
# of GitHub OIDC subjects (not every repo - see github_deployment_role_subjects).
# Unlike eks.tf's github-eks-deploy role (scoped to describe+admin one cluster),
# this one can do anything in the account. Previously assumed to pre-exist via
# this account's own bootstrap process; a freshly-created account needs it
# created here instead (see enable_github_deployment_role_admin_access in
# eks.tf for the EKS-cluster-admin-access side of this same role).
resource "aws_iam_role" "github_deployment" {
  count = var.enable_github_deployment_role ? 1 : 0
  name  = "github-deployment-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_deployment_role_subjects
          }
        }
      }
    ]
  })

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }

  lifecycle {
    precondition {
      condition     = length(var.github_deployment_role_subjects) > 0
      error_message = "github_deployment_role_subjects must list at least one OIDC subject when enable_github_deployment_role is true."
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_deployment_admin" {
  count      = var.enable_github_deployment_role ? 1 : 0
  role       = aws_iam_role.github_deployment[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
