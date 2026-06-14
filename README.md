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

Each cluster's Flux reconciles only its own path.

## GitOps structure (Layer 2)

Canonical Flux layout (`clusters/` + `infrastructure/` + `apps/` with `dependsOn`
ordering) **plus Kustomize Components** for à-la-carte feature composition — the
"third path": canonical ordering and a single monorepo, with brainfair-style
menu composition but native and without a second repo. Details, including the
base / overlay / component distinction: [`kubernetes/README.md`](kubernetes/README.md).

## Secrets

Real secrets only via **SOPS** (age), rules in `.sops.yaml` (one key per cluster).
Everything else (IPs, domains, ports, topology) is public: the compensating control
is node hardening, not obscurity.

## Dependency layers

- Own roles/modules live in this repo (`ansible/roles/`, `terraform/modules/`).
- Community ones are pinned (`ansible/requirements.yml`, terraform `version`), not vendored.
