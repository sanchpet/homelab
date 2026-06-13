# homelab

Monorepo for managing personal infrastructure. Three IaC layers:

| Layer | What | With | Directory |
|-------|------|------|-----------|
| **Layer 0** | VPS provisioning | Terraform/OpenTofu (later) | `terraform/` |
| **Layer 1** | node bootstrap: OS prep + k3s | Ansible | `ansible/` |
| **Layer 2** | cluster state: infra + apps | Flux GitOps | `kubernetes/` |

## Multi-cluster

Each cluster is a `kubernetes/clusters/<name>/` directory with its own bootstrap path:

```bash
flux bootstrap github --owner=<owner> --repository=homelab \
  --path=kubernetes/clusters/ips-usa-vps-2
```

Each cluster's Flux reconciles only its own path. `infrastructure/` and `apps/` are
organized as `base/` (reusable) + `<cluster>/` (overlay, Kustomize).

## Secrets

Real secrets only via **SOPS** (age), rules in `.sops.yaml` (one key per cluster).
Everything else (IPs, domains, ports, topology) is public: the compensating control
is node hardening, not obscurity.

## Dependency layers

- Own roles/modules live in this repo (`ansible/roles/`, `terraform/modules/`).
- Community ones are pinned (`ansible/requirements.yml`, terraform `version`), not vendored.
