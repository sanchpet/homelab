# Layer 0 — Provisioning (Terraform / OpenTofu)

Not used yet: the current VPS was provisioned manually.

Provider modules will land here once declarative **re-provisioning** is needed
(requires the VPS provider to expose an API).

Structure (when we get there):

```
terraform/
  modules/        # own reusable modules
  live/           # environments; call modules/ + community (pinned source+version)
```
