# Kubernetes — Layer 2 (Flux GitOps)

Desired cluster state, reconciled by Flux. Structure follows the canonical
[fluxcd/flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
plus **Kustomize Components** for à-la-carte composition (the "third path", below).

## Layout

```
kubernetes/
  clusters/<name>/          # Flux wiring for one cluster (NOT manifests)
    flux-system/            #   gotk components + sync (written by `flux bootstrap`)
    infra-crds.yaml         #   Flux Kustomization → infrastructure/crds
    infra-controllers.yaml  #   → infrastructure/controllers (dependsOn: infra-crds)
    infra-configs.yaml      #   → infrastructure/<name>     (dependsOn: infra-controllers)
    apps.yaml               #   → apps/<name>               (dependsOn: infra-configs)
  infrastructure/
    base/<component>/       # complete platform resources (cert-manager, NGF, gateway-api)
    crds/                   # layer 1: CRDs only (shared)            ← infra-crds
    controllers/            # layer 2: operators (shared)            ← infra-controllers
    components/<feature>/   # reusable, optional MODIFICATIONS (issuers, ...)
    <name>/kustomization.yaml   # layer 3: per-cluster configs (Gateway, issuers) ← infra-configs
  apps/
    base/<app>/             # complete workload definitions (sandbox, 3x-ui, anylink)
    components/<feature>/   # reusable modifications (HTTPRoute wiring, ...)
    <name>/kustomization.yaml
```

## The three building blocks (don't confuse them)

| Block | Grammatically | Holds | Rule of thumb |
|-------|---------------|-------|---------------|
| **base** | a *noun* (a thing) | complete resources (Deployment, HelmRelease) | a self-contained thing that's either present or not |
| **overlay** (`<name>/`) | the *assembler* for one cluster | `resources:` (which base) + `patches:` + `components:` | per-cluster composition |
| **component** | a *verb* (a modification) | `kind: Component` — patches / extra resources / generators, toggled on per overlay | a feature/policy you want to include selectively and reuse |

Test for base vs component: *"do I want to toggle this independently and reuse it
across components or clusters?"* → **component**. Otherwise → **base**.

## clusters/ holds wiring, not manifests

`clusters/<name>/` contains only Flux **Kustomization CRs** (pointers) + `flux-system/`.
The actual manifests live in `infrastructure/` and `apps/`. Cluster-specific manifests
go in the **overlay** (`infrastructure/<name>/`, `apps/<name>/`) — either as extra
`resources:` or as `patches:` to base.

## Ordering — explicit layers, not retry-until-it-works

A single infra Kustomization mixing CRDs, operators and the resources that *use* them
races on first reconcile (`no matches for kind "Gateway"` until the CRDs land). Instead the
infra is split into Flux Kustomizations chained with `dependsOn` + `wait: true`:

```
infra-crds  →  infra-controllers  →  infra-configs  →  apps
(Gateway API   (cert-manager, NGF,    (Gateway, certs,   (workloads)
 CRDs)          reloader)              ClusterIssuers)
```

`wait: true` makes each layer block until its objects (incl. a nested CRD Kustomization)
are Ready, so the next layer never references a kind that isn't installed yet. `infra-crds`
+ `infra-controllers` point at the **shared** `infrastructure/{crds,controllers}`;
`infra-configs` at the **per-cluster** `infrastructure/<name>`. cert-manager ships its own
CRDs via its chart (in controllers); only the Gateway API CRDs need the explicit crds layer.

## What runs here

**Applications** (`apps/base/<app>/`, namespace `vpn` unless noted):

| App | Exposure (node port) | Purpose |
|-----|----------------------|---------|
| `3x-ui` | `443` Reality + Gateway `8443` (subs) | VLESS-Reality — stealth VPN access from RU |
| `anylink` | `4443` TCP+DTLS (hostNetwork) | OpenConnect SSL-VPN — laptops/phones + Keenetic router |
| `gost` | `7443` http+tls, `1443` socks5+tls | TLS-wrapped proxy — DPI-resistant from RU |
| `sandbox` | — | placeholder for learning workloads (R-014) |

> Port map (single-IP node): `443`=Reality · `4443`=anylink · `7443`/`1443`=gost.
>
> OpenVPN (flant/ovpn-admin) was trialled and removed — the v0.0.3 chart needed too many
> postRenderer workarounds (wrong image, no redirect-gateway, double-NAT, iptables backend
> mismatch on hostNetwork). Reality + gost + anylink cover the need. If protocol diversity
> is ever wanted, prefer adding a 3x-ui inbound (Hysteria2/TUIC) over a new deployment.

**Infrastructure** (`infrastructure/base/<component>/`):

| Component | Purpose |
|-----------|---------|
| `cert-manager` | Let's Encrypt certs (HTTP-01 via the Gateway) |
| `nginx-gateway-fabric` + `gateway-api` | Gateway API controller + CRDs (Traefik disabled in k3s) |
| `reloader` (stakater) | **auto-restart pods on ConfigMap/Secret change** |
| `system-upgrade-controller` | GitOps k3s upgrades (Ф3, placeholder) |
| `letsencrypt` (component) | `letsencrypt-staging` / `-prod` ClusterIssuers |

> **Reloader convention (use it, don't `kubectl rollout restart`):** a workload that mounts
> a ConfigMap/Secret which changes should carry `reloader.stakater.com/auto: "true"` on its
> Deployment — Reloader (installed cluster-wide) watches and restarts it. Our app-template
> apps set it under `controllers.<name>.annotations`; for third-party charts that don't,
> add it via a HelmRelease `postRenderers` patch.

## The "third path": canonical + Kustomize Components

Why this over the two common alternatives:

- **vs canonical-only** (overlay lists base verbosely): Components add à-la-carte
  feature composition natively — toggle a feature with one line in `components:`,
  reuse it across clusters. No per-cluster duplication.
- **vs two-repo / bundles** (e.g. flux-head/flux-infra): same à-la-carte ergonomics
  without the overhead of a second repo, an app-of-apps indirection, or a home-grown
  bundle mechanism. One monorepo, atomic cross-layer commits, official Flux + official
  Kustomize feature (longevity).

Per-cluster overlay = assembly from a menu:

```yaml
# infrastructure/ips-usa-vps-2/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:                      # things: what to install (base)
  - ../base/gateway-api-crds
  - ../base/cert-manager
  - ../base/nginx-gateway-fabric
components:                     # modifications: which features to enable
  - ../components/letsencrypt-prod
  - ../components/monitoring
```

A second cluster reuses the same base + components, differing by a single line
(e.g. omit `monitoring`).

> `components/` is introduced at the first real à-la-carte need (a feature wanted on
> some clusters but not others). Until then overlays just list base — no premature
> structure.

## Bootstrap

Each cluster is bootstrapped to its own path. Flux installs its controllers, commits
its own manifests under `clusters/<name>/flux-system/`, and starts reconciling.

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

If the workstation's link to the API server is slow or unstable, bootstrap **from the
node itself**, where the API is local (`127.0.0.1:6443`) and the discovery/openapi
fetch is instant. Flux controllers run in-cluster afterwards, so the workstation link
no longer matters for reconciliation.

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

## Multi-cluster

Flux for each cluster reconciles only its own `clusters/<name>/` tree. Mirrors the
`ansible/inventory/<cluster>/` layout. Add a cluster = new `clusters/<name>/` +
`infrastructure/<name>/` + `apps/<name>/`, then bootstrap to that path.
