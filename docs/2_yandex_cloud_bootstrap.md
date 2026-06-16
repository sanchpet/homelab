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

## 2.3 State location

These two bootstrap units keep **local** state by design (they create the backend, so they
can't be on it from the start). That's fine for a solo setup — the resources persist in YC
and can be re-imported if the local state is lost. **Every other unit** (e.g.
`terraform/live/threexui/`) uses the S3 backend automatically via `root.hcl` once the bucket
and `AWS_*` keys exist.

Optional — move the bootstrap state into S3 too (durability): add an
`include "root" { path = find_in_parent_folders("root.hcl") }` block to each unit, then:

```bash
cd ../yc-folder      && terragrunt init -migrate-state
cd ../yc-s3-tf-state && terragrunt init -migrate-state
```

> If `init` errors on checksums against Yandex S3, export
> `AWS_REQUEST_CHECKSUM_CALCULATION=when_required`. Backend flags
> (`skip_s3_checksum`, `disable_bucket_update`, region `us-east-1`) are in
> `terraform/live/root.hcl`.

Next: [3_vps_bootstrap.md](3_vps_bootstrap.md).
