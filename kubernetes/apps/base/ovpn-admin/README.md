# ovpn-admin (OpenVPN + web UI)

[flant/ovpn-admin](https://github.com/flant/ovpn-admin) — an OpenVPN server with a web UI
to manage users/certs (`vpn` namespace). Its role in the fleet is **protocol diversity**:
a plain OpenVPN endpoint for clients/friends to fall back to where VLESS/Reality gets
blocked but OpenVPN slips through (and vice-versa). Not a stealth replacement for Reality
— "copy a `.ovpn`, it connects".

## Why this one, and the pinning caveats

No maintained "vanilla openvpn, mount your own config" k8s image exists (kylemanna/ptlange
are dead). flant/ovpn-admin is actively maintained and gives a UI to add a friend and
download their `.ovpn` in two clicks. Trade-offs we accept:

- **Combined image.** `ghcr.io/palark/ovpn-admin/ovpn-admin` bundles the Go admin binary
  **and** openvpn + easy-rsa (see its Dockerfile), so the chart runs that one image as both
  containers (`/app/ovpn-admin` and `/entrypoint.sh`). The chart's `openvpn.repo` value is
  vestigial/unused.
- **Only `:master` exists** upstream (no semver tags — werf content-hash tags + `master`).
  The chart hardcodes `:master`, so we pin to a **digest** via a HelmRelease `postRenderers`
  kustomize image override. Re-resolve when bumping:
  `crane digest ghcr.io/palark/ovpn-admin/ovpn-admin:master`.
- **Chart not published** to a Helm repo → consumed from a Flux `GitRepository` pinned to a
  reviewed commit. Chart is **v0.0.3** (immature) — expect to validate on-cluster.

## Networking

OpenVPN runs over **TCP 1194** on the node. The pod is **`hostNetwork`** (postRenderer
patch), not the chart's default hostPort: a routing VPN must NAT client traffic out the
node, and without hostNetwork the traffic is double-NAT'd (pod MASQUERADE → node SNAT) and
the **return path breaks** (egress goes out but no replies come back). hostNetwork gives a
single MASQUERADE on the node — the same model anylink uses. No port clash: `443`=Reality,
`4443`=anylink, `7443`/`1443`=gost, `1194`=OpenVPN. Two hostNetwork VPNs (anylink + this)
coexist: different ports, different tun devices, non-overlapping client subnets
(`10.99.99.0/24` vs `172.16.200.0/24`), subnet-scoped MASQUERADE rules. The container uses
caps (`NET_ADMIN`/`NET_RAW`/`MKNOD`/…), not full `privileged`. `strategy: Recreate` —
node:1194 is exclusive, so RollingUpdate would deadlock. `externalHost` (cluster overlay) is
the address written into generated `.ovpn` files.

## PKI — in Kubernetes Secrets (no PVC)

ovpn-admin runs with `--storage.backend="kubernetes.secrets"`: the CA, certs and CCD live
as **k8s Secrets** in the `vpn` namespace (the chart grants RBAC for it), not a PVC and not
Git. Panel-managed runtime state, like 3x-ui's DB — lose the namespace's secrets and the
PKI is gone. (Back up the CA secret.)

## Admin UI — private, reached via SSH tunnel

The UI listens on **`:8000`** and has **no built-in auth**. On `hostNetwork` that would be
public on `node:8000`, so an init container (`restrict-admin-ui`) adds a node firewall rule
**dropping `:8000` from any non-loopback interface** — only loopback (and thus an SSH
tunnel) can reach it. `ingress.enabled: false` too.

Two equivalent ways in — both arrive over loopback, so the firewall allows them:

```bash
# A) SSH tunnel straight to the node (works even when the cluster API is throttled)
ssh -L 8000:127.0.0.1:8000 sanchpet@vps-2.usa.ips.sanch.pet -N
#    → browse http://localhost:8000

# B) via the cluster (kubectl connects to the pod over loopback)
kubectl -n vpn port-forward svc/ovpn-admin 8000:8000
#    → browse http://localhost:8000
```

A direct hit on `http://<node>:8000` from the internet is dropped by the firewall rule.

### Add / revoke a friend

1. Open the UI (tunnel above) → **create a user** → it issues a client cert.
2. **Download that user's `.ovpn`** (CA + client cert/key + `remote vps-2.usa.ips.sanch.pet
   1194 tcp` already baked in).
3. Send it → the friend imports it into **OpenVPN Connect / Tunnelblick** and connects.
   **Revoke** from the same UI when needed (updates the CRL).

> Status: validated on-cluster (image/MASQUERADE/egress) after the hostNetwork fix — the
> chart is v0.0.3, so re-check after any pin bump.
