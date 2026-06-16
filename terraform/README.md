# Terraform

Engine: **Terraform**, driven by **Terragrunt**. Toolchain pinned in the repo-root
`mise.toml` (`terraform`, `terragrunt`, `terraform-docs`, `tflint`, `trivy`). Terraform
(not OpenTofu): the Yandex ecosystem targets the Terraform registry; OpenTofu's lags badly.

```
terraform/
  modules/
    threexui-panel/   # configure a 3x-ui panel (inbounds/clients) via the threexui provider
    yc-folder/        # a Yandex Cloud folder (own thin module)
  live/
    root.hcl          # shared remote state (Yandex S3, S3-native locking)
    yandex-cloud/
      yc-folder/      # the "homelab" folder        (bootstrap unit, local state)
      yc-s3-tf-state/ # the state bucket + admin SA  (bootstrap unit, local state)
    threexui/
      ger/            # the ips-ger-vps 3x-ui panel  (terragrunt unit, S3 state)
```

Standing it up from scratch: [`docs/`](../docs/) (numbered runbooks).

## Panel configuration (active — WP-043)

`modules/threexui-panel` manages 3x-ui inbounds + clients as code via the community
provider `batonogov/threexui`, closing the "config lives in SQLite, not Git" caveat
(`kubernetes/apps/base/3x-ui/README.md`). One terragrunt unit per panel under `live/`.

### Remote state (Yandex Object Storage)

State is in an S3-compatible Yandex bucket (`sanchpet-homelab-tfstate`), locking is
S3-native (`use_lockfile`, Terraform ≥ 1.11 — no DynamoDB). The bucket + a storage-admin
service account are created by the `live/yandex-cloud/` bootstrap units — see
[`docs/2_yandex_cloud_bootstrap.md`](../docs/2_yandex_cloud_bootstrap.md). The backend
authenticates with that SA's **static access key** through the `homelab` AWS profile
(`AWS_PROFILE=homelab` is auto-set by the root `mise.toml`; the keys live in
`~/.aws/credentials`, never in Git):

```sh
aws configure --profile homelab set aws_access_key_id     <static-key-id>
aws configure --profile homelab set aws_secret_access_key <static-key-secret>
```

> If `terraform init` errors on checksums against Yandex S3, export
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
