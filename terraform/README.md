# Terraform / OpenTofu

Engine: **OpenTofu** (drop-in for Terraform, MPL-2.0), driven by **Terragrunt**. Toolchain
pinned in `terraform/mise.toml` (`opentofu`, `terragrunt`; `TG_TF_PATH=tofu`).

Two concerns live here:

```
terraform/
  modules/
    threexui-panel/   # configure a 3x-ui panel (inbounds/clients) via the threexui provider
  live/
    root.hcl          # shared remote state (Yandex S3, S3-native locking)
    threexui/
      ger/            # the ips-ger-vps 3x-ui panel  (terragrunt unit)
```

## Panel configuration (active — WP-043)

`modules/threexui-panel` manages 3x-ui inbounds + clients as code via the community
provider `batonogov/threexui`, closing the "config lives in SQLite, not Git" caveat
(`kubernetes/apps/base/3x-ui/README.md`). One terragrunt unit per panel under `live/`.

### Remote state (Yandex Object Storage)

State is in an S3-compatible Yandex bucket, locking is S3-native (`use_lockfile`,
OpenTofu ≥ 1.10 — no DynamoDB). Credentials are a Yandex **static access key** via the
environment, never in Git:

```sh
export AWS_ACCESS_KEY_ID=<static-key-id>
export AWS_SECRET_ACCESS_KEY=<static-key-secret>
```

Bootstrap once (chicken-and-egg — the bucket holds the state, so it can't be created by
this state). Create `homelab-tofu-state` against `https://storage.yandexcloud.net`
(`yc storage bucket create` or AWS CLI with the Yandex endpoint) before the first apply.

> If `tofu init` errors on checksums against Yandex S3, export
> `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` (newer AWS SDK adds a checksum Yandex
> rejects).

### Apply a panel (ger)

The panel is ClusterIP-only — open a tunnel so `http://localhost:2053` reaches it:

```sh
# VPN off:  ssh -L 2053:<xui-panel-clusterIP>:2053 <ger-node>
# VPN on:   kubectl port-forward -n vpn svc/xui-panel 2053:2053

cd terraform/live/threexui/ger
cp secrets.sops.yaml.example secrets.sops.yaml   # fill real panel creds, then:
sops --encrypt --in-place secrets.sops.yaml      # needs the repo age key
terragrunt apply                                  # needs the age private key to decrypt
```

`secrets.sops.yaml` (panel admin user/pass + `webBasePath`) is SOPS-encrypted; the age
private key must be available locally (`SOPS_AGE_KEY_FILE` or `~/.config/sops/age/keys.txt`).

Adding a panel = a new `live/threexui/<panel>/` (its own `terragrunt.hcl` + `secrets.sops.yaml`).

## Layer 0 — provisioning (later)

VPS provisioning stays manual for now (the current provider exposes no API). Provider
modules land under `modules/` + `live/` once declarative re-provisioning is possible.
