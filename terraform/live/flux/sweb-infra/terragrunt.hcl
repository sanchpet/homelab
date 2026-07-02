# live/flux/sweb-infra — declarative Flux bootstrap for the RU infra hub (ADR-0002).
#
# Seeds the Flux Operator + the FluxInstance via the ControlPlane community module
# (community-first). Terraform owns ONLY the ephemeral seed (ns + temp RBAC + a Job that
# applies the operator + FluxInstance); Flux then adopts and reconciles from
# kubernetes/clusters/sweb-infra. Run against THIS cluster's kubeconfig:
#   export KUBECONFIG=<sweb-infra kubeconfig>   # ansible writes it world-readable on the node
#   cd terraform/live/flux/sweb-infra && terragrunt apply
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
# cluster's kubeconfig (KUBECONFIG env, sweb-infra context).
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    # Both providers target the sweb-infra cluster. The TF kubernetes provider does NOT
    # read kubectl's KUBECONFIG by default (it looks for KUBE_CONFIG_PATH) — so bake the path
    # in from the exported KUBECONFIG at generate time. helm v3: kubernetes is an attribute.
    provider "kubernetes" {
      config_path = "${get_env("KUBECONFIG", "~/.kube/config")}"
    }
    provider "helm" {
      kubernetes = {
        config_path = "${get_env("KUBECONFIG", "~/.kube/config")}"
      }
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
    instance_yaml = file("${get_repo_root()}/kubernetes/clusters/sweb-infra/flux-system/flux-instance.yaml")
    operator_chart = {
      values_yaml = file("${get_repo_root()}/kubernetes/clusters/sweb-infra/flux-system/flux-operator-values.yaml")
    }
  }
}
