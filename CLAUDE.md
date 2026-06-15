# homelab — instructions for Claude Code

> Monorepo for personal infrastructure: `ansible/` (Layer 1) + `kubernetes/` Flux
> (Layer 2) + `terraform/` (Layer 0, later).

## Workflow

### 1. PR

- Create feature branch from `main`
- Commit changes (small, focused commits with `--signoff`)
- Push branch, create draft PR via `gh pr create --draft`
- Wait for CI

### 2. Merge

- **Do NOT self-merge.** Creating and pushing the PR is fine; merging is the owner's call.
  After CI is green, **send the owner the direct PR link and ask whether to merge or if
  they have comments.** Wait for an explicit go-ahead ("merge it" / "мержи") before
  merging. Always include the clickable PR URL when reporting a PR.
- When approved, merge with **`gh pr merge --squash`** (not `--rebase`). Rebase-merge
  rewrites commits and strips the local commit signature → GitHub shows them
  **Unverified**. Squash lets GitHub sign the resulting commit → **Verified**, and keeps
  history linear. See PACK-devops DEVOPS.FM.011.

## Principle: community-first for roles and modules (BLOCKING)

**Where a battle-tested community role / module / collection / helm chart exists, take
it as the base and extend it with your own tasks/patches/overlays. Do not hand-roll
what the community already maintains.**

- **Complex/standard domain** (hardening, monitoring, cert-manager, DBs, ingress) →
  community base, **pin the version** (`requirements.yml` / terraform `version`). Own
  differences go as extra tasks on top (`import_role` + own tasks), not a fork.
- **Trivial domain** (baseline packages, day-0 access) → thin own tasks; don't pull in
  community for its own sake.
- **Before hand-rolling**, check for a maintained community alternative (and that it is
  NOT abandoned — the xanmanning.k3s lesson).
- Extract your own code into a separate repo only for a deliberate OSS release (later).

**Reference in this repo:** the `hardening` role imports `devsec.hardening.os_hardening`
+ `ssh_hardening` (community base) and adds fail2ban + an override of
`net.ipv4.ip_forward=1` on top (k3s/VPN need forwarding, devsec disables it). The
`bootstrap` (day-0) and `common` (baseline) roles are own — trivial domain.

## Ansible roles

| Role | Concern | Applied | Origin |
|------|---------|---------|--------|
| `bootstrap` | day-0: create admin user + key + passwordless sudo, lock root & password auth | once (`bootstrap.yml`, run `-u root -k`) | own |
| `common` | baseline: packages, timezone, unattended-upgrades | always, on `all` | own |
| `hardening` | CIS/SSH hardening + fail2ban | always, on `all` | community (devsec) + own |

> **k3s is not an own role.** Installed via the official `k3s.orchestration` collection
> (k3s team, maintained), tag pinned in `requirements.yml`, configured through the
> inventory (`server_config_yaml`). Precedent: an own k3s role was dropped as a
> community-first violation (the official collection turned out to be maintained and
> consumable).

## Kubernetes app pattern (BLOCKING)

Apps are deployed via the **bjw-s `app-template`** generic chart (HelmRelease +
per-app OCIRepository pinning the chart), not raw Deployment/Service YAML — repo-wide,
the home-ops standard. Cross-cutting resources (Certificate/cert-manager,
ExternalSecret/ESO, raw Secrets/ConfigMaps) are **sibling manifests** in the same app
dir, composed by the Flux Kustomization — app-template owns the workload, not other
operators' CRs. Reference: `apps/base/anylink` (app-template) + `apps/ips-usa-vps-2/anylink/`
(its cert/config/secret). `3x-ui` is still raw Kustomize → pending migration to
app-template for consistency. Don't mix generic-chart + raw for the *same* workload
(the anti-pattern).

**Cluster overlay layout (BLOCKING):** group per app/component, no flat prefixed files.
`apps/<cluster>/<app>/` holds de-prefixed files (`config.yaml`, `certificate.yaml`,
`secret.sops.yaml`) + a `kustomization.yaml` pulling in `../../base/<app>`; the cluster
`kustomization.yaml` lists the app dirs. Same for `infrastructure/<cluster>/<component>/`.
Never dump `app-config.yaml`/`app-certificate.yaml` flat in the cluster dir.

## Secrets

Real secrets via **SOPS** (age). The age **public** key is in `.sops.yaml`
(`encrypted_regex: ^(data|stringData)$`); secret files are named `*.sops.yaml`. The age
**private** key lives only as the `sops-age` Secret in `flux-system` (created
out-of-band on the node) and in the owner's password manager — never in Git. Flux
Kustomizations decrypt via `spec.decryption: { provider: sops, secretRef: sops-age }`.
Encrypt only what's secret: e.g. anylink's `server.toml` is a plaintext ConfigMap;
only `LINK_ADMIN_PASS`/`LINK_JWT_SECRET` go in a SOPS Secret (env override).

IPs / domains / ports are **public** (the control is node hardening, not obscurity).
A secret-in-disguise (tokenized URLs, node tokens) goes into SOPS even if it looks
like config. (Self-hosted secret store — Vault/Infisical — is a planned upgrade off SOPS.)

## Multi-cluster

A cluster = `kubernetes/clusters/<name>/` + its own `flux bootstrap --path=...` +
`infrastructure|apps/{base,<cluster>}` (Kustomize) + one SOPS key per cluster.
