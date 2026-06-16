# 2. Yandex Cloud — Terraform state bootstrap (Layer 0)

Create the **folder** and the **S3 bucket** that hold Terraform state, with Terraform. Both
are *bootstrap units*: they run on **local** state first (the bucket can't store its own
state before it exists — chicken-and-egg), then their state is migrated into S3.

Auth is from the environment (set automatically, see [1_init_repo.md](1_init_repo.md)):
`YC_TOKEN`, `YC_CLOUD_ID`, `TF_STATE_BUCKET`.

Both units ship with `include "root"` (S3 backend). On a from-zero bootstrap the bucket
doesn't exist yet, so the **first** apply must run on local state — comment out the
`include "root" { … }` block in each unit's `terragrunt.hcl` for 2.1–2.2 (the unit header
flags this), then restore it in 2.3.

## 2.1 Folder (local state)

```bash
cd terraform/live/yandex-cloud/yc-folder
terragrunt apply
```

## 2.2 State bucket + storage-admin service account (local state)

```bash
cd ../yc-s3-tf-state
terragrunt apply        # creates the bucket + storage-admin SA

# the SA static key → the AWS-style env the S3 backend uses (keep out of shell history):
export AWS_ACCESS_KEY_ID=$(terragrunt output -raw storage_admin_access_key)
export AWS_SECRET_ACCESS_KEY=$(terragrunt output -raw storage_admin_secret_key)
```

## 2.3 Migrate the bootstrap state into S3

**Restore** the `include "root"` block in both units (so their backend is S3), then migrate —
do this **right after 2.2** (don't clear `.terragrunt-cache` in between, or the local state is
lost):

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
