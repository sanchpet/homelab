# Bootstrap — from zero to a running cluster

Numbered runbooks, in order. Each is a terse "run these commands" guide; the *why* lives
in the per-layer READMEs (`ansible/`, `kubernetes/`, `terraform/`) and `CLAUDE.md`.

| # | Doc | Layer | What |
|---|-----|-------|------|
| 1 | [1_init_repo.md](1_init_repo.md) | — | prerequisites + repo init (mise, age, yc, pre-commit) |
| 2 | [2_yandex_cloud_bootstrap.md](2_yandex_cloud_bootstrap.md) | 0 | YC folder + S3 Terraform-state bucket + SA, then migrate state |
| 3 | [3_vps_bootstrap.md](3_vps_bootstrap.md) | 1 | Ansible: day-0 user lockdown + hardening + k3s |
| 4 | [4_kubernetes_bootstrap.md](4_kubernetes_bootstrap.md) | 2 | Flux GitOps bootstrap + SOPS age key |
| 5 | [5_apps.md](5_apps.md) | 2 | the VPN apps (anylink, gost, 3x-ui) + 3x-ui panel-as-code |

Layers 0–2 are independent enough to run out of order, but the first time go 1 → 5.
Per cluster (`ips-ger-vps`, `ips-usa-vps-2`) repeat 3 → 5 with that cluster's name.
