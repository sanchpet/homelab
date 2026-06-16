# 2. Yandex Cloud — Terraform state bootstrap (Layer 0)

Create the **folder** and the **S3 bucket** that hold Terraform state, with Terraform. Both
are *bootstrap units*: they run on **local** state first (the bucket can't store its own
state before it exists — chicken-and-egg), then their state is migrated into S3.

Auth is from the environment (set automatically, see [1_init_repo.md](1_init_repo.md)):
`YC_TOKEN`, `YC_CLOUD_ID`, `TF_STATE_BUCKET`.

## 2.1 Folder

```bash
cd terraform/live/yandex-cloud/yc-folder
terragrunt apply
```

## 2.2 State bucket + storage-admin service account

```bash
cd ../yc-s3-tf-state
terragrunt apply
# static access key for the S3 backend:
terragrunt output -raw storage_admin_access_key
terragrunt output -raw storage_admin_secret_key
```

Feed the key to the AWS-style env the S3 backend uses (Yandex Object Storage is
S3-compatible). Keep it out of shell history / put it in a profile:

```bash
export AWS_ACCESS_KEY_ID=$(terragrunt output -raw storage_admin_access_key)
export AWS_SECRET_ACCESS_KEY=$(terragrunt output -raw storage_admin_secret_key)
```

## 2.3 Migrate the bootstrap state into S3

The two units created the backend on **local** state (it didn't exist yet). Now that the
bucket exists, move them onto S3 so they live with every other unit — do this **right after
2.2** (don't clear `.terragrunt-cache` in between, or the local state is lost). Per unit, add
the include to its `terragrunt.hcl`:

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

then migrate:

```bash
cd ../yc-folder      && terragrunt init -migrate-state   # answer "yes"
cd ../yc-s3-tf-state && terragrunt init -migrate-state
```

After this, all state is in S3. **Every other unit** (e.g. `terraform/live/threexui/`)
already uses S3 via `root.hcl`.

> If `init` errors on checksums against Yandex S3, export
> `AWS_REQUEST_CHECKSUM_CALCULATION=when_required`. Backend flags
> (`skip_s3_checksum`, `disable_bucket_update`, region `us-east-1`) are in
> `terraform/live/root.hcl`.

> **Lost the local state before migrating** (e.g. the folder already exists but no state)?
> Re-import, then migrate — a YC folder name is unique per cloud, so re-applying would
> conflict: `terragrunt import yandex_resourcemanager_folder.this <folder-id>`
> (`<folder-id>` from `yc resource-manager folder list`).

Next: [3_vps_bootstrap.md](3_vps_bootstrap.md).
