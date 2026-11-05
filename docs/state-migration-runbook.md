# State migration runbook: 6 roots → 1 (agnostk sandbox first)

**Status: not yet executed.** This repo has only been refactored at the file level so
far (see the root README). No `terraform state mv` has been run against the real Vault
backend. This doc is the plan for doing that, starting with the `agnostk` sandbox
account before touching `develop`/`demo`/`prod`.

Requires `VAULT_ADDR` + `VAULT_TOKEN` (for the `<your-state-backend>`
HTTP backend) and AWS credentials for the `agnostk` account. Run everything from a
scratch directory, not this repo's working tree, so a mistake can't corrupt the actual
`.tf` files.

## 0. Why this is lower-risk than it sounds

On `agnostk` specifically:

- **`networking`**: the comment in the old `eks/environment-tfvars/agnostk.tfvars`
  says this component's state is "empty; do not create a second VPC" - agnostk's EKS
  already hardcodes the pre-existing CloudFormation VPC/subnets via `vpc_id`/
  `private_subnets` instead of using this module's output. Expect `terraform state
  list` on this component to come back empty or near-empty.
- **`database`, `opensearch`, `s3`**: `deploy-to-aws.yml` hardcodes these three to
  `terraform_action: plan` regardless of the workflow's `terraform_action` input -
  they've likely never actually been applied on `agnostk`. Expect empty state.
- **`acm`** and **`eks` (kube-cluster)**: these ARE input-driven (can be applied for
  real) and `eks` in particular has a fully-populated `environment-tfvars/agnostk.tfvars`
  with real node groups - **treat these two as having real resources and migrate them
  last, most carefully, after proving the process on the empty ones.**

Confirm all of this with `terraform state list` in step 2 before assuming anything -
don't skip the verification just because it matches the prediction above.

## 1. Pull each component's current state

Old backend path convention (layer/component from `platform-infrastructure`'s
`deploy-to-aws.yml`):

| Component | Layer | Backend path (`aws/agnostk/<layer>/<component>`) |
| --- | --- | --- |
| networking | core | `aws/agnostk/core/networking` |
| acm | platform | `aws/agnostk/platform/acm` |
| database | platform | `aws/agnostk/platform/database` |
| s3 | platform | `aws/agnostk/platform/s3` |
| opensearch | platform | `aws/agnostk/platform/opensearch` |
| eks | platform | `aws/agnostk/platform/kube-cluster` |

For each row, in a scratch dir:

```bash
mkdir -p /tmp/tfstate-migration && cd /tmp/tfstate-migration

cat > backend-pull.tf <<'EOF'
terraform {
  backend "http" {}
}
EOF

terraform init -reconfigure \
  -backend-config="address=<your-state-backend>/v1/state/aws/agnostk/<layer>/<component>" \
  -backend-config="lock_address=<your-state-backend>/v1/lock/aws/agnostk/<layer>/<component>" \
  -backend-config="unlock_address=<your-state-backend>/v1/lock/aws/agnostk/<layer>/<component>" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="skip_cert_verification=true"

terraform state pull > <component>.tfstate
terraform state list -state=<component>.tfstate   # <- confirm what's really in there
```

Repeat for all 6 components before moving anything.

## 2. Build the combined state locally

Starting from an empty `combined.tfstate`, move every resource/module address found
in step 1 into it. Addresses are unchanged **except** the 6 `vault_export` modules,
which were renamed on the merge (`module.vault_export` → `module.vault_export_<component>`
per component) to avoid a name collision once they're all in one state:

```bash
for addr in $(terraform state list -state=networking.tfstate); do
  new_addr="$addr"
  [ "$addr" = "module.vault_export" ] && new_addr="module.vault_export_networking"
  terraform state mv -state=networking.tfstate -state-out=combined.tfstate "$addr" "$new_addr"
done
```

Repeat per component, substituting the right `vault_export_<component>` suffix
(`vault_export_acm`, `vault_export_database`, `vault_export_eks`,
`vault_export_networking`, `vault_export_opensearch`, `vault_export_s3`). Every other
address (the real resources: `module.vpc`, `module.eks_cluster`,
`module.eks_managed_node_group["system"]`, `module.postgres`, `aws_iam_role.alb_controller`,
etc.) carries over unchanged - that's the whole point of calling the shared modules
directly from one root instead of wrapping them in a renamed local module per
component, which would have forced an extra `module.<component>.` prefix onto every
single address here.

## 3. Push to the new combined backend path

Pick the new path with the team (not yet decided - placeholder below). Then:

```bash
cd /path/to/terraform-aws-infra
terraform init -reconfigure \
  -backend-config="address=<your-state-backend>/v1/state/aws/agnostk/platform/infra" \
  -backend-config="lock_address=<your-state-backend>/v1/lock/aws/agnostk/platform/infra" \
  -backend-config="unlock_address=<your-state-backend>/v1/lock/aws/agnostk/platform/infra" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="skip_cert_verification=true"

terraform state push /tmp/tfstate-migration/combined.tfstate
```

## 4. Verify before trusting it

```bash
AWS_PROFILE=agnostk terraform plan \
  -var-file=environment-tfvars/agnostk.tfvars \
  -var="environment=agnostk" \
  -var="profile=leanspace-aws" \
  -var="aws_region=eu-central-1"
```

**Expect zero changes.** Anything else (a replace, a tag-only diff you didn't expect,
a missing resource) means stop and go back - don't apply. Only after a clean plan
should the old 6 backend paths be considered safe to leave alone as a cold backup (not
deleted immediately).

## 5. Repeat for other environments

Only after `agnostk` is fully verified. Same steps, different environment name and
backend paths. `develop`/`demo`/`prod` almost certainly have real resources in all 6
components (unlike agnostk), so treat every one of those migrations as having real
blast radius from the start.
