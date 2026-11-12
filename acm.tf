data "aws_route53_zone" "selected" {
  count = var.enable_acm ? 1 : 0
  name  = var.domain_name
}

module "agnostk_certificate" {
  count  = var.enable_acm ? 1 : 0
  source = "git::https://github.com/leanspace/terraform-aws-modules.git//acm?ref=v0.1.5"

  domain_name               = var.domain_name
  route53_zone_id           = data.aws_route53_zone.selected[0].zone_id
  subject_alternative_names = var.alternative_names
  tags = {
    Name        = var.domain_name
    Environment = var.environment
  }
}

module "vault_export_acm" {
  count  = var.enable_acm ? 1 : 0
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/acm_certificate_arn"
      data  = { value = module.agnostk_certificate[0].certificate_arn }
    }
  ] : []
}
