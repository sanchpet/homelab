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

- Merge with **`gh pr merge --squash`** (not `--rebase`). Rebase-merge rewrites commits
  and strips the local commit signature → GitHub shows them **Unverified**. Squash lets
  GitHub sign the resulting commit → **Verified**, and keeps history linear. See
  PACK-devops DEVOPS.FM.011.

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

## Secrets

Only **SOPS** (age), one key per cluster (`.sops.yaml`). IPs / domains / ports are
**public** (the control is node hardening, not obscurity). A secret-in-disguise
(tokenized URLs, bootstrap/node tokens) goes into the vault even though it looks like config.

## Multi-cluster

A cluster = `kubernetes/clusters/<name>/` + its own `flux bootstrap --path=...` +
`infrastructure|apps/{base,<cluster>}` (Kustomize) + one SOPS key per cluster.
