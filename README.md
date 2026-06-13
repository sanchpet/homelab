# homelab

Монорепо управления личной инфраструктурой. Три слоя IaC:

| Слой | Что | Чем | Каталог |
|------|-----|-----|---------|
| **Layer 0** | провижининг VPS | Terraform/OpenTofu (позже) | `terraform/` |
| **Layer 1** | bootstrap узла: OS-prep + k3s | Ansible | `ansible/` |
| **Layer 2** | состояние кластера: инфра + приложения | Flux GitOps | `kubernetes/` |

## Мульти-кластер

Каждый кластер — папка `kubernetes/clusters/<имя>/` со своим bootstrap-путём:

```bash
flux bootstrap github --owner=<owner> --repository=homelab \
  --path=kubernetes/clusters/vps-stand
```

Flux каждого кластера реконсайлит только свой путь. `infrastructure/` и `apps/`
организованы как `base/` (переиспользуемое) + `<кластер>/` (overlay, Kustomize).

## Секреты

Настоящие секреты — только через **SOPS** (age), правила в `.sops.yaml` (ключ на
кластер). Всё остальное (IP, домены, порты, топология) — публично: компенсирующий
контроль — харднинг узла, не сокрытие. Подробнее — в политике безопасности проекта.

## Слои-зависимости

- Свои роли/модули — в этом репо (`ansible/roles/`, `terraform/modules/`).
- Community — пины (`ansible/requirements.yml`, terraform `version`), не вендорим.
