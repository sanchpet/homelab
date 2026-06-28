# live/flux/ips-ger-vps-2 — declarative Flux bootstrap for the Vault cluster (ADR-0002).
#
# Seeds the Flux Operator + the FluxInstance via the ControlPlane community module
# (community-first). Terraform owns ONLY the ephemeral seed (ns + temp RBAC + a Job that
# applies the operator + FluxInstance); Flux then adopts and reconciles from
# kubernetes/clusters/ips-ger-vps-2. Run against THIS cluster's kubeconfig:
#   export KUBECONFIG=<ips-ger-vps-2 kubeconfig>   # ansible writes it world-readable on the node
#   cd terraform/live/flux/ips-ger-vps-2 && terragrunt apply
#
# github-app.sops.yaml holds the GitHub App creds for the flux-system pullSecret (App scoped
# to sanchpet/homelab, rotatable — ADR-0002). Create it from the .example, then `sops -e`.

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
      kubernetes {}
    }
  EOF
}

locals {
  gh = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/github-app.sops.yaml"))
}

inputs = {
  revision = 1 # bump to force a bootstrap re-run

  gitops_resources = {
    instance_yaml = file("${get_terragrunt_dir()}/flux-instance.yaml")
  }

  # flux-system pullSecret referenced by the FluxInstance sync — GitHub App auth for git.
  managed_resources = {
    secrets_yaml = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name      = "flux-system"
        namespace = "flux-system"
      }
      type = "Opaque"
      stringData = {
        githubAppID             = tostring(local.gh.app_id)
        githubAppInstallationID = tostring(local.gh.installation_id)
        githubAppPrivateKey     = local.gh.private_key
      }
    })
  }
}
