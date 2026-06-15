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

Get the password first: `sops -d kubernetes/apps/ips-usa-vps-2/gost/secret.sops.yaml`
(user is `sanchpet`). Substitute it for `PASS` below.

### Quick CLI test (no install) — HTTP+TLS proxy

`curl` speaks an HTTPS proxy natively, so the `7443` listener works with a one-liner:

```bash
curl -x 'https://gost.vps-2.usa.ips.sanch.pet:7443' --proxy-user 'sanchpet:PASS' https://api.ipify.org
# → prints the VPS IP (193.218.188.197) = traffic egressed through gost
```

### Recommended — local gost → plain proxy → TLS to server (works for any app)

Most apps/browsers don't speak SOCKS/HTTP **over TLS**, so run a small local gost that
exposes a *plain* local proxy and forwards it over the TLS tunnel. Install gost on the
client (binary from [releases](https://github.com/go-gost/gost/releases), `brew install
gost`, or `mise use -g gost`), then:

```bash
# SOCKS5: local :1080 → TLS → server :1443
gost -L socks5://:1080 -F 'socks5+tls://sanchpet:PASS@gost.vps-2.usa.ips.sanch.pet:1443'

# or HTTP: local :8080 → TLS → server :7443
gost -L http://:8080 -F 'http+tls://sanchpet:PASS@gost.vps-2.usa.ips.sanch.pet:7443'
```

Then point apps/OS at the **plain local** proxy — `socks5://127.0.0.1:1080` (or
`http://127.0.0.1:8080`). The local→server hop is TLS (stealth, DPI-safe); the app→local
hop is plaintext on loopback (never leaves the machine).

- **System-wide (macOS):** System Settings → Network → … → Proxies → enable *SOCKS proxy*
  `127.0.0.1:1080` (covers most apps).
- **Browser:** point it at the local SOCKS/HTTP proxy (e.g. Firefox → Network Settings →
  Manual, SOCKS5 `127.0.0.1:1080`). Don't try to enter the remote `gost.…:1443` directly —
  the browser can't do SOCKS-over-TLS; that's the local gost's job.
- **CLI / per-app:** `ALL_PROXY=socks5://127.0.0.1:1080`, or curl `--socks5 127.0.0.1:1080`.
- **Keep it running:** background it (`gost … &`), or wrap in a launchd/systemd unit so the
  tunnel auto-starts.

> Phones: gost clients exist but are fiddly — for mobile prefer Reality (Shadowrocket /
> v2rayNG) which is built for it. gost shines on desktops/laptops.

## Image

Pinned to `gogost/gost:3.2.6` (latest stable v3). No official Helm chart → deployed via
the bjw-s `app-template` generic chart (repo-wide pattern), config + cert as sibling
SOPS/cert-manager resources in the cluster overlay.
