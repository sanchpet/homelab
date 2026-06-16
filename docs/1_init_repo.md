# 1. Initialize the repo

Dependencies: [mise](https://mise.jdx.dev/) (toolchain), [age](https://github.com/FiloSottile/age)
(SOPS key), [yc CLI](https://yandex.cloud/docs/cli/quickstart) (for the Terraform state on
Yandex). Everything else is installed by mise.

```bash
git clone git@github.com:sanchpet/homelab.git && cd homelab
mise trust          # the root mise.toml runs an env script (yc token) — trust it once
mise install        # terraform, terragrunt, terraform-docs, tflint, trivy, sops, age, kubectl, flux2, ...
```

The pre-commit hook installs itself (mise `postinstall` + `enter` hook). To run the gates
by hand: `pre-commit run --all-files`.

## Secrets key (SOPS / age)

SOPS decrypts with an **age** key. The **public** key is in `.sops.yaml` (committed); the
**private** key never is. Put it at the standard location so sops + terragrunt find it:

```bash
mkdir -p ~/.config/sops/age
# restore the private key from your password manager into:
#   ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt   # prints the public key — must match .sops.yaml
```

> Terragrunt's `sops_decrypt_file` reads the key only from `SOPS_AGE_KEY_FILE` (not the
> default path the sops CLI uses): `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`.

## Yandex auth (for the Terraform state backend)

```bash
yc init             # log in, pick the cloud/folder
```

The repo-root `mise.toml` then auto-exports, on entering the repo: `YC_CLOUD_ID`,
`TF_STATE_BUCKET` (static), and `YC_TOKEN` (a cached IAM token, refreshed ~every 11h by
`scripts/yc-token.sh`). Nothing to export by hand.

Next: [2_yandex_cloud_bootstrap.md](2_yandex_cloud_bootstrap.md).
