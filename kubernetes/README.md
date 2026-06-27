# Kubernetes — Flux GitOps (per-cluster layered layout)

Desired cluster state, reconciled by Flux. Layout follows
[ADR-0001](../docs/adr/0001-cluster-gitops-layout.md): **layered ports + functional
bundles + per-cluster variables**, single repo. A cluster is a *set of capabilities*
(like Ansible roles) selected per cluster, parameterized by that cluster's vars, ordered by
a small layer skeleton.

## Mental model

> **A cluster = `cluster-vars` + a selection of bundles across 4 ordered layers.**

- **Catalogs** (`crds/`, `infra/`, `apps/`) hold pure, reusable building blocks — no cluster
  names, no hardcoded versions (everything is a `${...}` placeholder).
- **Bundles** are curated `resources:` lists — a named capability (`platform`, `public-tls`,
  `vpn-gateway`, `vpn-stack`).
- **`clusters/<name>/`** is the only per-cluster dir: a `cluster-vars` ConfigMap + the 4
  layer Flux Kustomizations + the per-cluster *selection* (which bundles, plus the few
  genuinely-per-cluster customs).

## Layout

```
kubernetes/
├── crds/                      # CRD groups, hoisted, version via ${...}
│   └── gateway-api/           #   tag: ${gateway_api_version}
├── infra/
│   ├── base/                  # infra building blocks; HelmRelease version: ${...}
│   │   ├── cert-manager/      #   issuer-agnostic (CRDs still chart-managed — see note)
│   │   ├── nginx-gateway-fabric/
│   │   ├── reloader/
│   │   └── letsencrypt-issuers/   # ClusterIssuers; email via ${acme_email}
│   └── bundles/
│       ├── platform/          #   [cert-manager, nginx-gateway-fabric, reloader]
│       ├── public-tls/        #   [letsencrypt-issuers]   (runtime-needs platform)
│       └── vpn-gateway/       #   shared NGF gateway + sub cert (${cluster_subdomain})
├── apps/
│   ├── base/                  # 3x-ui, gost (gateway-agnostic); version: ${...}
│   └── bundles/
│       └── vpn-stack/         #   [3x-ui, gost] + sub HTTPRoute + gost cert
└── clusters/<name>/           # the ONLY per-cluster dir
    ├── kustomization.yaml     #   REQUIRED — scopes the root build (see gotcha)
    ├── flux-system/           #   gotk components + sync (flux bootstrap)
    ├── cluster-vars.yaml      #   ConfigMap: subdomain + ALL versions for this cluster
    ├── infra-crds.yaml        #   Flux KS → ../../crds                      wait
    ├── infra-controllers.yaml #   Flux KS → ./infra/controllers   dependsOn:infra-crds  wait
    ├── infra-configs.yaml     #   Flux KS → ./infra/config        dependsOn:infra-controllers
    ├── apps.yaml              #   Flux KS → ./apps                dependsOn:infra-configs  (sops)
    ├── infra/
    │   ├── controllers/       #   kustomization → [bundles/platform]
    │   └── config/            #   kustomization → [bundles/public-tls, bundles/vpn-gateway]
    └── apps/
        ├── kustomization.yaml #   → [bundles/vpn-stack, gost]
        └── gost/              #   per-cluster remainder: SOPS proxy creds only
```

## The 4 layers — explicit ordering, not retry-until-it-works

A single Kustomization mixing CRDs, operators and the resources that *use* them races on
first reconcile (`no matches for kind "Gateway"` until the CRDs land). Instead each cluster
chains four Flux Kustomizations with `dependsOn` + `wait: true`:

```
infra-crds  →  infra-controllers  →  infra-configs        →  apps
(Gateway API   (platform bundle:      (public-tls issuers +    (vpn-stack bundle +
 CRDs)          cert-manager, NGF,     vpn-gateway: gateway,     per-cluster SOPS)
                reloader)              sub cert)
```

`wait: true` makes a layer Ready only when its objects are healthy, so cert-manager is up
*before* a `ClusterIssuer`/`Certificate` applies — no NotReady window.

> **Layer names are preserved (`infra-crds/infra-controllers/infra-configs/apps`).**
> Renaming a Flux Kustomization with `prune: true` makes Flux delete the old object and GC
> its managed resources (cert-manager/NGF/issuers) while the new one recreates them — a
> control-plane blip. Keeping the names means a structure change is an in-place `path:`
> edit, not a rename. (ADR-0001's `crds/controllers/config` example names are illustrative.)

## ⚠️ The cluster dir MUST have an explicit `kustomization.yaml`

Without one, Flux generates a root kustomization via `kustomize create --autodetect
--recursive`, which **descends into `infra/` and `apps/` and applies the layer manifests RAW
at the root** `flux-system` Kustomization — no `postBuild` substitution, no ordering. A
`${...}` placeholder then reaches the API server unsubstituted (e.g. cert-manager rejects
`secretName: "${gateway_sub_tls_secret}"`), blocking the whole reconcile.

The explicit `clusters/<name>/kustomization.yaml` lists **only** the entrypoint
(`flux-system`, `cluster-vars.yaml`, the 4 layer KS) so the root never touches `infra/` /
`apps/`; the layers reach them via each KS's own `path:` (which carry `substituteFrom`).

## Bundles, à-la-carte, and what stays a per-cluster custom

A **bundle** is a `kustomization.yaml` with a `resources:` list — a curated capability.
Bundles must be **non-overlapping** (each component in exactly one bundle, else Kustomize
errors on duplicate resources).

| Bundle | Layer | Holds |
|--------|-------|-------|
| `platform` | controllers | cert-manager, nginx-gateway-fabric, reloader |
| `public-tls` | config | Let's Encrypt ClusterIssuers — **runtime-needs `platform`** (cert-manager); take them together |
| `vpn-gateway` | config | shared NGF gateway + sub TLS cert, parameterized by `${cluster_subdomain}` |
| `vpn-stack` | apps | 3x-ui + gost bases **plus** their gateway-facing pieces (sub HTTPRoute, gost cert) |

Rules of thumb:

- **Identical-modulo-`${cluster_subdomain}` → a parameterized bundle**, not a per-cluster
  custom. (gateway/cert/route differed only by subdomain → hoisted into bundles.)
- **Genuinely different → a per-cluster custom.** Today that is only **SOPS secrets**
  (`gost-config` proxy creds) and a future structurally-different gateway (the Vault host's
  `vault-https:443`).
- **À-la-carte** = list bases directly in a cluster's selection kustomization (no bundle).
  Use for one-offs (e.g. the Vault host taking only `apps/base/vault`); promote to a bundle
  only when a set is reused across ≥2 clusters.
- Bases stay **gateway-agnostic** — the bundle adds routing/cert, so a future non-VPN
  consumer of `base/3x-ui` doesn't drag a `sub-https` route.

## Versions: per-cluster, never floating

Bases omit hardcoded versions (`${...}`); each cluster pins **all** of them in
`cluster-vars` (subdomain + versions), substituted into every layer via
`postBuild.substituteFrom`. Never leave a version unset — Flux would float to latest
(non-reproducible). Per-cluster pinning is reproducible *and* enables canary / staged
rollout (bump one cluster's vars, validate, bump the rest). Automate bumps with Renovate.

```yaml
# clusters/ips-usa-vps-2/cluster-vars.yaml
data:
  cluster_subdomain: "vps-2.usa.ips.sanch.pet"
  acme_email: "ops@sanch.pet"
  gateway_sub_tls_secret: "sub-vps-2-tls"   # kept per cluster → no cert re-issue on changes
  gateway_api_version: "v1.5.1"
  cert_manager_version: "v1.20.2"
  ngf_version: "2.6.3"
  reloader_version: "2.2.12"
```

## What runs here

**Applications** (`apps/base/<app>/`, namespace `vpn`):

| App | Exposure (node port) | Purpose |
|-----|----------------------|---------|
| `3x-ui` | `443` Reality + Gateway `8443` (subs) | VLESS-Reality — stealth VPN access from RU |
| `gost` | `7443` http+tls, `1443` socks5+tls | TLS-wrapped proxy — DPI-resistant from RU |
| `sandbox` | — | placeholder for learning workloads (R-014) |

> Port map (single-IP node): `443`=Reality · `7443`/`1443`=gost.
>
> Decommissioned: **anylink** (OpenConnect) — poor throughput from RU, test only.
> **OpenVPN** (flant/ovpn-admin) — too many postRenderer workarounds. Reality + gost cover
> the need; for protocol diversity prefer adding a 3x-ui inbound (Hysteria2/TUIC) over a new
> deployment.

**Infrastructure** (`infra/base/<component>/`):

| Component | Purpose |
|-----------|---------|
| `cert-manager` | Let's Encrypt certs (HTTP-01 via the Gateway); issuer-agnostic |
| `nginx-gateway-fabric` + `gateway-api` | Gateway API controller + CRDs (Traefik disabled in k3s) |
| `reloader` (stakater) | **auto-restart pods on ConfigMap/Secret change** |
| `letsencrypt-issuers` | `letsencrypt-staging` / `-prod` ClusterIssuers (`public-tls` bundle) |

> **cert-manager CRDs** are still installed by its chart (`crds.enabled: true`). Hoisting
> them into `crds/cert-manager` (`crds.enabled: false`) is a planned follow-up — the
> Helm→Flux CRD ownership handoff is done deliberately under `flux reconcile`, see the TODO
> in `infra/base/cert-manager/helmrelease.yaml`.

> **Reloader convention (use it, don't `kubectl rollout restart`):** a workload that mounts
> a ConfigMap/Secret which changes should carry `reloader.stakater.com/auto: "true"` on its
> Deployment. Our app-template apps set it under `controllers.<name>.annotations`; for
> third-party charts that don't, add it via a HelmRelease `postRenderers` patch.

> **cert-manager Secrets survive Certificate deletion.** cert-manager runs without
> `--enable-certificate-owner-ref` (on purpose — it lets us rename a Certificate while
> keeping its Secret, so gateway TLS never re-issues). The cost: removing an app leaves its
> issued TLS Secret orphaned (not in Git, so Flux won't prune it) — delete it manually,
> e.g. `kubectl -n vpn delete secret anylink-tls`.

## Bootstrap

Each cluster is bootstrapped to its own path. Flux installs its controllers, commits its
manifests under `clusters/<name>/flux-system/`, and starts reconciling.

A GitHub PAT is required (fine-grained, this repo only, **Contents: RW** +
**Administration: RW** for the deploy key):

```bash
export GITHUB_USER=<owner>
export GITHUB_TOKEN=<pat>
flux check --pre
flux bootstrap github --owner=<owner> --repository=homelab --branch=main --path=kubernetes/clusters/<name> --personal
```

After it completes Flux pushes a commit to `main` (`git pull` to sync). The PAT can be
revoked afterwards — Flux uses the deploy key it created.

### Bootstrapping from the node (when the workstation can't reach the API reliably)

If the workstation's link to the API server is slow or unstable, bootstrap **from the node
itself**, where the API is local (`127.0.0.1:6443`):

```bash
# on the node
curl -s https://fluxcd.io/install.sh | sudo bash      # install flux CLI
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml            # local kubeconfig (k3s)
export GITHUB_USER=<owner>
export GITHUB_TOKEN=<pat>
flux check --pre
flux bootstrap github --owner=<owner> --repository=homelab --branch=main --path=kubernetes/clusters/<name> --personal
```

Verify: `flux get kustomizations` (all `Ready=True`) and `kubectl -n flux-system get pods`.

## Add a cluster

1. `flux bootstrap` to `kubernetes/clusters/<name>` (creates `flux-system/`).
2. Add `clusters/<name>/kustomization.yaml` (entrypoint only), `cluster-vars.yaml`, the 4
   layer KS, and `infra/{controllers,config}` + `apps/` selections picking the bundles the
   cluster needs.
3. Pin every version in `cluster-vars`. Reconcile cluster-by-cluster, verify health.

> Current clusters: `ips-ger-vps`, `ips-usa-vps-2` (VPN nodes — `platform` + `public-tls` +
> `vpn-gateway` + `vpn-stack`). Planned: `ips-ger-vps-2` (Vault host — `platform` +
> `public-tls` + à-la-carte `vault`).
