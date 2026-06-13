# homelab — инструкции для Claude Code

> Монорепо управления личной инфраструктурой: `ansible/` (Layer 1) + `kubernetes/`
> Flux (Layer 2) + `terraform/` (Layer 0, позже).

## Принцип: community-first для ролей и модулей (БЛОКИРУЮЩЕЕ)

**Где есть battle-tested community-роль / модуль / коллекция / helm-чарт — берём её
за основу и расширяем своими тасками/патчами/overlay. Не хэндролим то, что комьюнити
уже поддерживает.**

- **Сложный/типовой домен** (харднинг, мониторинг, cert-manager, БД, ingress) →
  community-база, **пин версии** (`requirements.yml` / terraform `version`). Свои
  отличия — отдельными тасками поверх (`import_role` + own tasks), не форком.
- **Тривиальный домен** (baseline-пакеты, day-0 доступ) → свои тонкие таски; не
  тащить community ради галочки.
- **Перед хэндроллом** проверить, есть ли поддерживаемая community-альтернатива
  (и что она НЕ заброшена — урок xanmanning.k3s).
- Своё выносим в отдельный репо только под осознанную OSS-публикацию (позже).

**Эталон в репо:** роль `hardening` импортирует `devsec.hardening.os_hardening` +
`ssh_hardening` (community-база) и поверх добавляет fail2ban + override
`net.ipv4.ip_forward=1` (k3s/VPN требуют форвардинг, devsec его глушит). Роли
`bootstrap` (day-0) и `common` (baseline) — свои, домен тривиальный.

## Роли Ansible

| Роль | Concern | Применяется | Происхождение |
|------|---------|-------------|---------------|
| `bootstrap` | day-0 доступ: ssh-ключ, отключить пароль | один раз (`bootstrap.yml`) | своё (тонкое) |
| `common` | baseline: пакеты, timezone, unattended-upgrades | всегда, на `all` | своё |
| `hardening` | CIS/SSH-харднинг + fail2ban | всегда, на `all` | community (devsec) + своё |

## Секреты

Только **SOPS** (age), ключ на кластер (`.sops.yaml`). IP / домены / порты —
**публичны** (контроль = харднинг узла, не сокрытие). Секрет-в-маскировке (токенные
URL, bootstrap/node-токены) — в vault, хоть и выглядит как config.

## Мульти-кластер

Кластер = `kubernetes/clusters/<имя>/` + свой `flux bootstrap --path=...` +
`infrastructure|apps/{base,<кластер>}` (Kustomize) + SOPS-ключ на кластер.
