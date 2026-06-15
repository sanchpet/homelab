# gost (GO Simple Tunnel — proxy)

[gost](https://github.com/go-gost/gost) as a **TLS-wrapped proxy** (`vpn` namespace).
Userspace, no TUN/privileged (like 3x-ui, unlike anylink). Two listeners, both wrapped in
real TLS so DPI sees plain HTTPS and doesn't classify them as a proxy — that's what makes
them **work from RU** (same reason Reality survives; a plain proxy would be throttled like
anylink). Reference: a friend's working `fh-vps/gost` setup.

## Listeners — TLS only, exposed via the node

| Port | gost service | Use |
|------|--------------|-----|
| `7443` | `http+tls` | HTTP CONNECT proxy over TLS |
| `1443` | `socks5+tls` | SOCKS5 proxy over TLS |

`service.type: LoadBalancer` → k3s servicelb (klipper) publishes both on the node. **No
cleartext proxy port on the public internet** (the reference exposes plain `8080`/`1080`
too — we don't: a cleartext proxy reachable from the internet leaks creds and is
DPI-visible). Ports don't clash: `443`=3x-ui Reality, `4443`=anylink, `7443`/`1443`=gost.

## DNS + cert (prerequisites)

The TLS listeners use a cert-manager Certificate (`gost-tls`) for
`gost.vps-2.usa.ips.sanch.pet`. Before gost can start you need:

1. DNS `gost.vps-2.usa.ips.sanch.pet` → node IP (HTTP-01 validation + client reach).
2. The cert issued (cert-manager, HTTP-01 via the Gateway) → `gost-tls` secret appears →
   gost mounts it at `/etc/gost/tls` and starts. (Until the secret exists the pod waits,
   same bootstrap ordering as anylink.)

## Config & auth — SOPS

The whole `gost.yml` (listeners + proxy auth) is one SOPS secret (`gost-config`), mounted
at `/etc/gost/gost.yml`. Reloader restarts gost on change. Username is `sanchpet`; read or
rotate the password with sops:

```bash
sops -d kubernetes/apps/ips-usa-vps-2/gost/secret.sops.yaml   # read
sops    kubernetes/apps/ips-usa-vps-2/gost/secret.sops.yaml   # edit → commit → Flux reconcile
```

## Client usage — run a local gost, point apps at it

Apps don't speak SOCKS/HTTP **over TLS** natively, so run a local gost that connects out
over the TLS tunnel and exposes a plain local proxy:

```bash
# SOCKS5: local :1080 → TLS → server :1443
gost -L socks5://:1080 -F 'socks5+tls://sanchpet:PASS@gost.vps-2.usa.ips.sanch.pet:1443'

# or HTTP: local :8080 → TLS → server :7443
gost -L http://:8080 -F 'http+tls://sanchpet:PASS@gost.vps-2.usa.ips.sanch.pet:7443'
```

Then point the app at `socks5://127.0.0.1:1080` (or `http://127.0.0.1:8080`). The
local→server hop is TLS (stealth); the app→local hop is plain on loopback.

## Image

Pinned to `gogost/gost:3.2.6` (latest stable v3). No official Helm chart → deployed via
the bjw-s `app-template` generic chart (repo-wide pattern), config + cert as sibling
SOPS/cert-manager resources in the cluster overlay.
