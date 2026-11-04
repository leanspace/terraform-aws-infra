data "aws_route53_zone" "selected" {
  name = var.domain_name
}

module "agnostk_certificate" {
  source = "git::https://github.com/leanspace/terraform-aws-modules.git//acm?ref=main"

  domain_name               = var.domain_name
  route53_zone_id           = data.aws_route53_zone.selected.zone_id
  subject_alternative_names = var.alternative_names
  tags = {
    Name        = var.domain_name
    Environment = var.environment
  }
}

module "vault_export_acm" {
  source = "git::https://github.com/leanspace/platform-infra-modules.git//vault?ref=main"

  create_secrets = var.enable_vault_export ? [
    {
      mount = "leanspace"
      path  = "${var.profile}/${var.environment}/acm_certificate_arn"
      data  = { value = module.agnostk_certificate.certificate_arn }
    }
  ] : []
}
