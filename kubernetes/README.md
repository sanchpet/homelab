# Kubernetes — Layer 2 (Flux GitOps)

Desired cluster state, reconciled by Flux. Structure follows the canonical
[fluxcd/flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
plus **Kustomize Components** for à-la-carte composition (the "third path", below).

## Layout

```
kubernetes/
  clusters/<name>/          # Flux wiring for one cluster (NOT manifests)
    flux-system/            #   gotk components + sync (written by `flux bootstrap`)
    infrastructure.yaml     #   Flux Kustomization → infrastructure/<name>
    apps.yaml               #   Flux Kustomization → apps/<name> (dependsOn: infrastructure)
  infrastructure/
    base/<component>/       # complete platform resources (cert-manager, NGF, CRDs)
    components/<feature>/   # reusable, optional MODIFICATIONS (monitoring, issuers)
    <name>/kustomization.yaml   # per-cluster overlay: select base + toggle components
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

## Ordering

`apps.yaml` has `dependsOn: infrastructure`, so Flux won't apply workloads until the
platform (CRDs, cert-manager, gateway) is reconciled green. CRDs → operators → apps.

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

## Multi-cluster

Each cluster is bootstrapped to its own path:

```bash
flux bootstrap github --owner=<owner> --repository=homelab \
  --path=kubernetes/clusters/<name>
```

Flux for each cluster reconciles only its own `clusters/<name>/` tree. Mirrors the
`ansible/inventory/<cluster>/` layout.
