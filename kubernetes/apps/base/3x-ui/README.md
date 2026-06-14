# 3x-ui (Xray panel)

Self-hosted Xray panel providing a VLESS-Reality endpoint (`vpn` namespace). Userspace
proxy — no TUN/privileged (unlike anylink).

## Networking — hostPort, not hostNetwork

Only the Reality inbound (**443**) is published to the host, via `hostPort`. The panel
(**2053**) stays on the pod network → **not publicly reachable**. This is the hardening:
the exposure is declared in the manifest (Git), not in a panel DB setting.

> **Gotcha:** `hostPort` is implemented by the `portmap` CNI plugin as an **iptables
> DNAT** (`host:443 → pod:443`), *not* a host listen socket. So `sudo ss -tlnp | grep 443`
> on the node shows **nothing** for 443 — that's expected, not a failure (only k3s API
> 6443 appears). Verify the path instead:
> - node → pod: `nc -vz <pod-ip> 443`
> - DNAT rule: `sudo iptables -t nat -S | grep 443` (look for `CNI-HOSTPORT-DNAT`)
> - end to end: `nc -vz <node> 443` from outside
>
> Adding an inbound on a new port requires adding that port as a `hostPort` here.
> `portmap` may SNAT the client source IP to the node IP (fine for Reality; panel
> traffic stats will show the node IP).

## Panel access (never public)

The panel is reached through the `xui-panel` ClusterIP service:

- **VPN on:** `kubectl port-forward -n vpn svc/xui-panel 2053:2053` → `http://localhost:2053`
- **VPN off:** `ssh -L 2053:<xui-panel-clusterIP>:2053 <node>` (one hop; the node reaches
  the ClusterIP). SSH interactive survives the DPI throttle.

Service is named `xui-panel`, not `3x-ui-panel`: Service names are DNS-1035 labels and
must **start with a letter** (the `3x-ui` Deployment name is fine — Deployments use the
looser DNS-1123 subdomain rule).

## Config lives in the DB, not Git (caveat)

Inbounds, clients, and the Reality keypair are stored in the SQLite DB on the `3x-ui-db`
PVC — **panel-managed, not in Git**. The manifest here is declarative; the runtime VPN
config is not. Lose the PVC → reconfigure from scratch.

A fully declarative alternative (xray-core + `config.json` from a ConfigMap, Reality
private key under SOPS) is a candidate migration — see the WP-040 notes. Bonus there:
recovery via a small `git push` (survives the throttle) + Flux-on-node apply, no working
VPN required to fix the VPN.

## Image

Pinned to `ghcr.io/mhsanaei/3x-ui:v3.3.1`. No official Helm chart exists (upstream ships
a Docker image + compose only), and the app is trivial → a thin manifest is the right
wrapper (community-first: we consume the official image, we don't hand-roll the app).
