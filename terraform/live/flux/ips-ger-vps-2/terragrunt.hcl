# live/flux/ips-ger-vps-2 — declarative Flux bootstrap for the Vault cluster (ADR-0002).
#
# Seeds the Flux Operator + the FluxInstance via the ControlPlane community module
# (community-first). Terraform owns ONLY the ephemeral seed (ns + temp RBAC + a Job that
# applies the operator + FluxInstance); Flux then adopts and reconciles from
# kubernetes/clusters/ips-ger-vps-2. Run against THIS cluster's kubeconfig:
#   export KUBECONFIG=<ips-ger-vps-2 kubeconfig>   # ansible writes it world-readable on the node
#   cd terraform/live/flux/ips-ger-vps-2 && terragrunt apply
#
# No git auth: the homelab repo is PUBLIC, so Flux pulls over anonymous HTTPS (no pullSecret,
# no GitHub App). In-repo secrets are SOPS-encrypted, decrypted in-cluster via the sops-age key.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # Community module (maintained, ControlPlane) — community-first ladder step 1.
  # Verify latest: https://registry.terraform.io/modules/controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes
  source = "tfr:///controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes?version=0.7.0"
}

# The bootstrap module talks to the target cluster — configure the providers from this
# cluster's kubeconfig (KUBECONFIG env, ips-ger-vps-2 context).
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "kubernetes" {}
    provider "helm" {
      # helm provider v3: `kubernetes` is an ATTRIBUTE (= {}), not a nested block (v2).
      # Empty → default kubeconfig loading rules (KUBECONFIG env).
      kubernetes = {}
    }
  EOF
}

inputs = {
  revision = 1 # bump to force a bootstrap re-run

  gitops_resources = {
    # The FluxInstance + operator values live in the GitOps tree (single source of truth); TF
    # only READS them to seed, then Flux reconciles them from git (dual lifecycle). The
    # operator_chart.values_yaml is the SAME file the in-git operator HelmRelease consumes —
    # seed and steady-state share one source of values.
    instance_yaml = file("${get_repo_root()}/kubernetes/clusters/ips-ger-vps-2/flux-system/flux-instance.yaml")
    operator_chart = {
      values_yaml = file("${get_repo_root()}/kubernetes/clusters/ips-ger-vps-2/flux-system/flux-operator-values.yaml")
    }
  }
}
