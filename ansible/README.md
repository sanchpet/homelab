# Ansible — Layer 1 (node bootstrap)

Brings fresh hosts into a managed state and installs k3s.

## Layout

| Path | Purpose |
|------|---------|
| `ansible.cfg` | fleet-wide `remote_user` (connection user, populates `{{ ansible_user }}`) |
| `vars/fleet.yml` | fleet-global vars (admin user, SSH key) — identical for every cluster |
| `inventory/<cluster>/hosts.ini` | per-cluster topology (`server`/`agent`/`k3s_cluster`) |
| `inventory/<cluster>/group_vars/k3s_cluster.yml` | per-cluster k3s vars (version, server config) |
| `roles/bootstrap` | day-0: create admin user + key + passwordless sudo, lock root |
| `roles/common` | baseline (packages, timezone, unattended-upgrades) |
| `roles/hardening` | `devsec.hardening` (CIS/SSH) + fail2ban |
| `playbooks/bootstrap.yml` | day-0 (run once, as root) |
| `playbooks/site.yml` | steady-state (common + hardening + k3s) |

## Multi-cluster

The `k3s.orchestration` collection hardcodes the group names `server`/`agent`/
`k3s_cluster`, so **each cluster is its own inventory directory**. Pass it explicitly:

```bash
ansible-playbook -i inventory/<cluster>/ playbooks/site.yml
```

Per-cluster vars (k3s version, server config) live in that cluster's `group_vars/`;
fleet-global vars (SSH key, admin user) live once in `vars/fleet.yml`. Mirrors the
Flux `kubernetes/clusters/<cluster>/` layout.

> **`cluster_context` is required per cluster.** The collection merges each cluster's
> kubeconfig into `~/.kube/config` under `cluster_context`, which defaults to
> `k3s-ansible` for *every* cluster — so a second cluster silently overwrites the first's
> context. Each `group_vars/k3s_cluster.yml` sets `cluster_context: <cluster>`. To
> re-import a context after a fix: `ansible-playbook -i inventory/<cluster>/ playbooks/site.yml --tags kubeconfig`.

## Prerequisites

Tooling is managed with mise + uv. The repo-root `mise.toml` provides the cluster
binaries; `ansible/mise.toml` adds Python + uv. mise merges both when you `cd` here.

```bash
cd ansible
mise install     # python, uv (this layer) + sops, age, kubectl, flux (root, merged)
mise run deps    # uv sync + ansible-galaxy install -r requirements.yml
```

Then set `ansible_host` in `inventory/<cluster>/hosts.ini`.

## 1. Day-0 bootstrap — run ONCE, as root (special invocation)

A fresh host only has `root` + a password. This run connects **as root** (not the
steady-state `sanchpet`), creates the admin user with the SSH key and passwordless
sudo, then disables root SSH login and password authentication.

```bash
ansible-playbook -i inventory/ips-usa-vps-2/ playbooks/bootstrap.yml -u root -k
```

- `-u root` — overrides the steady-state `ansible_user` (sanchpet) **for this run only**.
- `-k` (`--ask-pass`) — prompts for the root SSH password.

> ⚠️ Keep the VPS provider's web console open during this step. The play asserts the
> SSH key is set and validates sudoers (`visudo -cf`) and sshd (`sshd -t`) before
> applying, but the console is your way back in if something still goes wrong.

After this completes, **root SSH is disabled** — do not run bootstrap as root again.

## 2. Steady-state — key-based, as the admin user

```bash
ansible-playbook -i inventory/ips-usa-vps-2/ playbooks/site.yml
```

Runs baseline + hardening on all hosts, then installs k3s on the server node(s) via
the official `k3s.orchestration` collection. Connects as `sanchpet` over the SSH key;
passwordless sudo means no `--ask-become-pass`.
