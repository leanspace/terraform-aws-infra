# Shared across multiple components below - declared once here instead of
# once per component now that acm/database/eks/networking/opensearch/s3 all
# live in a single root (and therefore a single state) instead of each being
# applied separately with its own copy of these data sources.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
