# Vault — single-node secret store (cluster: ips-ger-vps-2)

HashiCorp Vault on a dedicated single-node k3s cluster, exposed at
`https://vault.vps-2.ger.ips.sanch.pet`. Storage: integrated Raft (single voter). TLS is
terminated at the NGF Gateway; auto-unseal uses a locally-stored key (see below).

Decision record and the secret-store comparison/ArchGate live in the governance repo
(WP-042). Reference for the unseal pattern: `itruslan/homelab-gitops`.

## Layout (ADR-0001)

- `kubernetes/apps/base/vault/` — reusable Vault deploy (Helm release + auto-unsealer).
- `kubernetes/clusters/ips-ger-vps-2/apps/vault/` — per-cluster overlay (HTTPRoute).
- `kubernetes/infra/bundles/vault-gateway/` — dedicated Gateway listener + cert bundle.
- `kubernetes/clusters/ips-ger-vps-2/` — Flux entrypoint (cluster-vars + layer KS).
- `terraform/live/flux/ips-ger-vps-2/` — declarative Flux bootstrap (operator + FluxInstance, ADR-0002).
- `ansible/inventory/ips-ger-vps-2/` — node bootstrap + k3s install.

## Bring-up order

1. **Provision the VPS** (ipserver, Germany). Target: 2 vCPU / 4 GB / ~40 GB NVMe,
   **swap disabled**, NTP enabled. Node `vps-2.ger.ips.sanch.pet` with a wildcard
   `*.vps-2.ger.ips.sanch.pet` (as elsewhere) → `vault.vps-2.ger.ips.sanch.pet` resolves to it.

2. **Ansible — node + k3s** (from `ansible/`):
   ```sh
   ansible-galaxy install -r requirements.yml
   ansible-playbook -i inventory/ips-ger-vps-2/ playbooks/bootstrap.yml -u root -k
   ansible-playbook -i inventory/ips-ger-vps-2/ playbooks/site.yml
   ```

3. **Seed Flux declaratively** (Flux Operator + FluxInstance via Terraform — ADR-0002, not
   the CLI). One-time: create a GitHub App (Repository contents → Read-only) installed on
   `sanchpet/homelab`, and fill `terraform/live/flux/ips-ger-vps-2/github-app.sops.yaml`
   (from the `.example`). Then:
   ```sh
   export KUBECONFIG=<ips-ger-vps-2 kubeconfig>
   cd terraform/live/flux/ips-ger-vps-2 && terragrunt apply
   ```
   Terraform applies the operator + FluxInstance (ephemeral seed); Flux then reconciles the
   cluster from git. No committed `flux-system/` (the FluxInstance creates the GitRepository).

4. **Wait for `vault-0`** to be Running (it will be **sealed** — expected).

5. **Initialize Vault once** (imperative, not GitOps):
   ```sh
   kubectl -n vault exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1
   ```
   Record the **unseal key** and **root token** → store in the password manager.

6. **Create the unseal key Secret out-of-band** (kept out of Git, like the sops-age key):
   ```sh
   kubectl -n vault create secret generic vault-unseal-keys \
     --from-literal=key-1=<unseal_key>
   ```
   The `vault-unseal` Deployment unseals `vault-0` within ~30 s.

7. **Verify** `https://vault.vps-2.ger.ips.sanch.pet` (UI) and `kubectl -n vault exec vault-0 --
   vault status` (`Sealed false`).

## Backups

Raft snapshots (schedule a CronJob later):
```sh
kubectl -n vault exec vault-0 -- vault operator raft snapshot save /tmp/vault.snap
kubectl -n vault cp vault-0:/tmp/vault.snap ./vault-$(date +%F).snap
```

## Security notes

- **Unseal key & root token are out-of-band** (password manager + the `vault-unseal-keys`
  Secret), never committed — same model as the sops-age key.
- TLS is terminated at the Gateway; in-cluster `:8200` is plaintext but node-local on this
  single-node cluster.
- After setup, create scoped policies/tokens and stop using the root token for daily work.

## Not in this scaffold (next phase)

- **ESO on the consumer clusters** (`ips-ger-vps`, `ips-usa-vps-2`) pointing at this Vault
  (Kubernetes auth method), then incremental migration of secrets off SOPS — SOPS stays as
  backup until cut-over.
- **Vault config as code** via the `vault` Terraform provider (mounts / policies / auth /
  roles). Keep secret *values* out of Terraform state.
