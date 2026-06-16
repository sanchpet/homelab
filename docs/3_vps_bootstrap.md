# 3. VPS bootstrap — Ansible (Layer 1)

Bring a fresh VPS into a managed state and install k3s. Run per cluster
(`ips-ger-vps`, `ips-usa-vps-2`). Tooling:

```bash
cd ansible
mise install     # python + uv (this layer) merged with the root toolchain
mise run deps    # uv sync + ansible-galaxy install -r requirements.yml
```

Set the node's DNS in `inventory/<cluster>/hosts.ini` (`ansible_host=`). Admin user
(`sanchpet`) and SSH public key are in `vars/fleet.yml`.

## 3.1 Day-0 — run ONCE, as root

A fresh host has only `root` + a password. This connects **as root**, creates the admin
user (key + passwordless sudo), then disables root login and password auth.

```bash
ansible-playbook -i inventory/<cluster>/ playbooks/bootstrap.yml -u root -k
```

- `-u root` overrides the steady-state user for this run only; `-k` prompts for the root
  password.
- The play **asserts the SSH key is set** and validates sudoers/sshd before touching
  anything — but keep the provider's **web console open** as a fallback.
- After it finishes, **root SSH is off** — never run `bootstrap.yml` as root again.

## 3.2 Steady-state — key-based, as the admin user

```bash
ansible-playbook -i inventory/<cluster>/ playbooks/site.yml
```

Runs `common` (packages, timezone, unattended-upgrades) + `hardening` (devsec CIS/SSH +
fail2ban) on all hosts, then installs k3s on the server node via the official
`k3s.orchestration` collection. k3s config comes from `group_vars/k3s_cluster.yml`
(`k3s_version`, Traefik disabled — we run NGINX Gateway Fabric via Flux instead,
`write-kubeconfig-mode: 0644`). No `--ask-become-pass` — passwordless sudo.

> The collection merges the cluster's kubeconfig into `~/.kube/config` under
> `cluster_context: <cluster>` (set per cluster so a second cluster doesn't overwrite the
> first). The import runs on **first setup only** — see `ansible/README.md` to re-import
> a context later.

Verify: `kubectl --context <cluster> get nodes` → the server node is `Ready`.
Next: [4_kubernetes_bootstrap.md](4_kubernetes_bootstrap.md).
