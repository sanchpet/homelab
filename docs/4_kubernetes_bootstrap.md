# 4. Kubernetes bootstrap — Flux GitOps (Layer 2)

Hand the cluster to Flux. It installs its controllers, commits its own manifests under
`kubernetes/clusters/<cluster>/flux-system/`, and reconciles the `infra → apps` chain.

A fine-grained **GitHub PAT** (this repo only, **Contents: RW** + **Administration: RW**
for the deploy key) is needed for bootstrap; it can be revoked afterwards (Flux uses the
deploy key it creates).

## 4.1 Bootstrap

```bash
export GITHUB_USER=sanchpet
export GITHUB_TOKEN=<pat>
flux check --pre
flux bootstrap github --owner=sanchpet --repository=homelab --branch=main \
  --path=kubernetes/clusters/<cluster> --personal
```

> **From the node** if the workstation's link to the API is slow (the cluster lives
> abroad — DPI throttling): SSH in, `curl -s https://fluxcd.io/install.sh | sudo bash`,
> `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml`, then the same `flux bootstrap`. The API
> is local (`127.0.0.1:6443`) there, so discovery is instant; reconciliation runs
> in-cluster afterwards regardless of the workstation link.

## 4.2 SOPS age key (so Flux can decrypt secrets)

The apps Kustomization decrypts SOPS secrets with the `sops-age` Secret in `flux-system`
(`spec.decryption.secretRef.name: sops-age`). Create it out-of-band from the **age private
key** that matches `.sops.yaml`:

```bash
kubectl --context <cluster> -n flux-system create secret generic sops-age \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt
```

Do this once per cluster. Without it, any Kustomization that decrypts secrets (anylink,
gost) stays `NotReady` with a decryption error.

## 4.3 Verify

```bash
flux get kustomizations           # all Ready=True
kubectl -n flux-system get pods    # controllers Running
git pull                           # sync the commit Flux pushed to main
```

Next: [5_apps.md](5_apps.md).
