# Ansible — Layer 1 (node bootstrap)

Brings a fresh host into a managed state and installs k3s.

## Layout

| Path | Purpose |
|------|---------|
| `inventory/hosts.ini` | topology only (groups, hosts, `ansible_host`) |
| `inventory/group_vars/all.yml` | vars for every host (admin user, SSH key) |
| `inventory/group_vars/k3s_cluster.yml` | k3s cluster vars (version, server config) |
| `roles/bootstrap` | day-0: create admin user + key + passwordless sudo, lock root |
| `roles/common` | baseline (packages, timezone, unattended-upgrades) |
| `roles/hardening` | `devsec.hardening` (CIS/SSH) + fail2ban |
| `playbooks/bootstrap.yml` | day-0 (run once, as root) |
| `playbooks/site.yml` | steady-state (common + hardening + k3s) |

## Prerequisites

From the repo root, set up the toolchain (Python, uv, Ansible, cluster CLIs) via mise:

```bash
mise install     # python, uv, sops, age, kubectl, flux
mise run deps    # uv sync + ansible-galaxy install -r ansible/requirements.yml
```

Then set the host IP in `inventory/hosts.ini` (replace `REPLACE_WITH_IP`).

## 1. Day-0 bootstrap — run ONCE, as root (special invocation)

A fresh host only has `root` + a password. This run connects **as root** (not the
steady-state `sanchpet`), creates the admin user with the SSH key and passwordless
sudo, then disables root SSH login and password authentication.

```bash
ansible-playbook playbooks/bootstrap.yml -u root -k
```

- `-u root` — overrides the steady-state `ansible_user` (sanchpet) **for this run only**.
- `-k` (`--ask-pass`) — prompts for the root SSH password.

> ⚠️ Keep the VPS provider's web console open during this step. The play asserts the
> SSH key is set and validates sudoers (`visudo -cf`) and sshd (`sshd -t`) before
> applying, but the console is your way back in if something still goes wrong.

After this completes, **root SSH is disabled** — do not run bootstrap as root again.

## 2. Steady-state — key-based, as the admin user

```bash
ansible-playbook playbooks/site.yml
```

Runs baseline + hardening on all hosts, then installs k3s on the server node(s) via
the official `k3s.orchestration` collection. Connects as `sanchpet` over the SSH key;
passwordless sudo means no `--ask-become-pass`.
