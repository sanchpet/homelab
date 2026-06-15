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

OpenVPN runs over **TCP 1194**, published on the node via `hostPort` (`openvpn.inlet:
HostPort`). No clash: `443`=Reality, `4443`=anylink, `7443`/`1443`=gost, `1194`=OpenVPN.
The container uses Linux caps (`NET_ADMIN`/`NET_RAW`/`MKNOD`/…), not full `privileged`.
`externalHost` (cluster overlay) is the address written into generated `.ovpn` files.

## PKI — in Kubernetes Secrets (no PVC)

ovpn-admin runs with `--storage.backend="kubernetes.secrets"`: the CA, certs and CCD live
as **k8s Secrets** in the `vpn` namespace (the chart grants RBAC for it), not a PVC and not
Git. Panel-managed runtime state, like 3x-ui's DB — lose the namespace's secrets and the
PKI is gone. (Back up the CA secret.)

## Admin UI — private, SSH tunnel

The UI (`:8000`, ClusterIP `ovpn-admin`, headless) has no built-in auth and isn't exposed
publicly (`ingress.enabled: false`). Reach it over an SSH tunnel:

```bash
kubectl -n vpn port-forward svc/ovpn-admin 8000:8000   # via the cluster
# or straight to the node if you prefer: ssh -L 8000:<clusterIP>:8000 <node>
```
Then open `http://localhost:8000`.

## Add a friend (the whole point)

1. In the UI → create a user → it issues a client cert.
2. Download that user's **`.ovpn`** (CA + client cert/key + `remote <externalHost> 1194
   tcp` baked in).
3. Send it to the friend → they import it into **OpenVPN Connect** (any OS) → connect.
   Revoke from the UI when needed.

> Status: first cut, **needs on-cluster validation** (PKI init, UI add-user, `.ovpn`
> connect) — the chart is v0.0.3.
