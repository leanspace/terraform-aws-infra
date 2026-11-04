# terraform-aws-infra

AWS infrastructure for the Leanspace platform: ACM, Aurora Postgres, EKS, networking (VPC),
OpenSearch, and S3, as a **single Terraform root with a single state**.

## Structure

Each component calls the shared modules in
[platform-infra-modules](https://github.com/leanspace/platform-infra-modules) directly -
there is no local wrapper module per component. One file per component, all in this one
root:

| File | Component |
| --- | --- |
| `acm.tf` | ACM certificate |
| `rds.tf` | Aurora Postgres + its KMS key (`rds-kms-policy.json.tpl`) |
| `eks.tf` | EKS cluster, node groups, addons, IRSA roles |
| `networking.tf` | VPC, subnets, flow logs, endpoints, VPC Lattice |
| `opensearch.tf` | OpenSearch domain + its KMS key (`opensearch-kms-policy.json.tpl`) |
| `s3.tf` | Platform S3 buckets (toggleable, disabled by default) |

Plus root-level `variables.tf`, `outputs.tf`, `versions.tf` (required providers + the
Vault-backed HTTP backend), `provider.tf`, and `common.tf` (data sources shared by more
than one component).

Components reference each other's resources directly (e.g. `rds.tf` uses
`module.vpc.vpc_id` and `module.eks_cluster.node_security_group_id`) instead of reading
another root's state over `terraform_remote_state` - there's only one state now.

## This used to be 6 separate roots

Until recently, `acm/`, `database/`, `eks/`, `networking/`, `opensearch/`, and `s3/` were
each an independently-applied Terraform root (own state, own CI job in
`platform-infrastructure`'s `deploy-to-aws.yml`), stitched together with
`terraform_remote_state` reads. They've been consolidated into this single root. See
[`docs/state-migration-runbook.md`](./docs/state-migration-runbook.md) for the plan to
migrate each environment's existing state into the new combined state - **no live state
has been migrated yet**; this repo is file-level-only until that runbook is run.

The CI workflow that applies these components (`platform-infrastructure`'s
`deploy-to-aws.yml`, currently 6 separate jobs) has **not** been updated yet - that's
pending internal team sign-off on this restructuring.

## Environments

`environment-tfvars/<environment_name>.tfvars` holds the per-environment overrides (one
file per environment, merged across what used to be per-component tfvars). These are
gitignored (real VPC/subnet IDs, bucket names, etc. in a public repo) - copy
`environment-tfvars/example.tfvars.example` to get started. `agnostk` is the sandbox
account; `develop` currently only carries EKS overrides.

## Disabling a component

`enable_networking`, `enable_acm`, `enable_database`, and `enable_opensearch` (all
default `true`) skip creating that component entirely. This matters most for
`enable_networking`: during the agnostic migration, `agnostk`'s VPC already exists from
a CloudFormation stack and this root shouldn't create a second one. Set
`enable_networking = false` and pass the existing VPC directly via `vpc_id` /
`private_subnets` / `public_subnets` - every component that needs VPC info (`eks.tf`,
`rds.tf`, `opensearch.tf`) resolves it through `local.vpc_id` / `local.private_subnets`
in `common.tf`, which fall back to those variables instead of reading `module.vpc`
directly. A validation rule enforces that `vpc_id` is set whenever
`enable_networking = false`. EKS itself doesn't have a toggle - it's assumed to always
be deployed - and S3 is already opt-in per bucket (see above), so it doesn't need one
either.

## Enabling an S3 bucket

Every bucket this component knows about (see `local.known_bucket_names` in `s3.tf`)
defaults to disabled. To turn specific ones on for an environment, add an entry to that
environment's tfvars that sets `s3_buckets`, keyed by the known bucket's name:

```hcl
s3_buckets = {
  # Turn on a known bucket, keeping all its other defaults (versioning,
  # encryption, etc.) as-is.
  "logs-chunks" = {
    enabled = true
  }

  # A brand-new, ad-hoc bucket this component doesn't know about by
  # default -- any key that isn't one of the known bucket names works the
  # same way.
  "my-custom-exports" = {
    enabled       = true
    name          = "totally-custom-bucket-name"
    sse_algorithm = "AES256"
    policy_json = jsonencode({
      Version   = "2012-10-17"
      Statement = []
    })
  }
}
```
