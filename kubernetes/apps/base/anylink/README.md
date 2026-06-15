# anylink (OpenConnect SSL-VPN)

Self-hosted [anylink](https://github.com/cherts/anylink) — an AnyConnect/OpenConnect
compatible SSL-VPN server (`vpn` namespace). Routes and NATs client traffic on the node
→ needs a TUN device + `iptables` NAT → runs **`privileged` + `hostNetwork`** (unlike
3x-ui, which is a userspace proxy on `hostPort`).

Use cases: laptop/phone (Cisco Secure Client / `openconnect`) and a home router
(Keenetic OpenConnect) as a whole-LAN tunnel. Reality (3x-ui) covers stealth client
access from RU; anylink covers "normal" full-tunnel devices.

## Networking — hostNetwork, binds the node directly

`hostNetwork: true` → anylink binds the node's `:4443` **TCP + UDP (DTLS)** directly (see
`server_addr`/`server_dtls_addr` in the cluster ConfigMap). The egress master interface is
`eth0` (`ipv4_master`), clients get `10.99.99.0/24` (`ipv4_cidr`), MASQUERADE'd out via
`iptables_nat = true`.

- Port is **4443**, not 443: 443 on this single-IP node is already taken by 3x-ui Reality.
- Verify the listener on the node: `sudo ss -tlnp | grep 4443` (with `hostNetwork` it **is**
  a real listen socket, unlike 3x-ui's `hostPort` DNAT).
- End to end from outside: `nc -vz <node> 4443` and a TLS probe
  `curl -vk https://anylink.<domain>:4443/` (expect `200 OK` + the Let's Encrypt cert).

## Admin panel — private, SSH tunnel only

`admin_addr = "127.0.0.1:8800"` → the panel listens on the node's **loopback**, never
public. With `hostNetwork`, `127.0.0.1` is the node's loopback, so reach it with an SSH
tunnel (no `kubectl port-forward` — the panel isn't on the pod network):

```bash
ssh -L 8800:127.0.0.1:8800 <node> -N
# then browse http://localhost:8800 — login: admin / <password>
```

(`<node>` = `vps-2.usa.ips.sanch.pet`. SSH interactive survives the DPI throttle.)

## Secret — `LINK_ADMIN_PASS` is a bcrypt HASH

`server.toml` ships as a plaintext ConfigMap; only `LINK_ADMIN_PASS` + `LINK_JWT_SECRET`
live in a SOPS Secret (env override of the toml placeholders). `LINK_ADMIN_PASS` is the
**bcrypt hash**, not the plaintext — anylink bcrypt-compares the entered password against
it. Generate with anylink's own tool (Go bcrypt `$2a$`; htpasswd's `$2y$` is rejected):

```bash
docker run --rm cherts/anylink:0.14.2 ./anylink tool -p 'YourPassword'
```

> **Gotcha:** the tool prints `Passwd:$2a$10$...`. Put **only the hash** in the secret —
> strip the `Passwd:` prefix. Leaving it in stores `Passwd:$2a$...` as the "hash" → every
> login fails. (This bit us once.) Then log in with `admin` / `YourPassword` (plaintext).

Reloader (`reloader.stakater.com/auto`) restarts the pod when the secret/ConfigMap/cert
changes, so a `sops` edit + Flux reconcile is enough — no manual rollout.

## VPN users & groups

VPN accounts are **panel-managed** (Users in the admin panel), separate from the panel
`admin`. The `group_list` the client sees comes from the server's groups; `default_group`
is the fallback. A user's **Groups** field is a multi-select — **one user can belong to
several groups** — but the client picks exactly **one** group per connection (see
`authgroup` below). Groups carry their own routing/ACL/DNS policy, so multi-group lets one
account choose a profile at connect time.

## Keenetic (KeeneticOS) OpenConnect client — setup

The Keenetic **GUI is a dead end** for a non-443 port: the "Server address" field silently
strips `:4443` back to `https://host`. Configure via CLI (`ssh admin@<router>`), because
Keenetic's CLI uses a two-token `upstream <host> <port>` form that keeps the port (the
`https://host` scheme form forces 443).

Working interface block (mirror this — `OpenConnect1` here):

```
interface OpenConnect1
    description anylink.vps-2.usa.ips
    role misc
    security-level public
    authentication identity <vpn-user>
    authentication password <vpn-password>
    ip tcp adjust-mss pmtu
    openconnect upstream anylink.vps-2.usa.ips.sanch.pet 4443
    openconnect protocol anyconnect
    openconnect authgroup all
    openconnect allow-basic-auth
    openconnect accept-addresses
    openconnect accept-routes
    openconnect connect via PPPoE0
    up
```

Then `system configuration save`. Bring it up / re-test with:

```
interface OpenConnect1 down
interface OpenConnect1 up
show log              # watch the openconnect lines
```

### The three directives the GUI won't set — and why each matters

| Directive | Without it |
|-----------|-----------|
| `openconnect protocol anyconnect` | Keenetic doesn't negotiate the AnyConnect dialect anylink speaks |
| `openconnect authgroup <group>` | anylink returns a group-select form → Keenetic (non-interactive) can't choose → **`User input required in non-interactive mode` → service stops in a loop** |
| `openconnect allow-basic-auth` | basic-auth fallback for the AnyConnect login form |

> **The headline gotcha:** the symptom of a missing `authgroup` is **total silence in the
> anylink server log** (anylink doesn't log the pre-auth XML exchange) while Keenetic's own
> `show log` shows `Connected to HTTPS … (TLS1.3)` → `User input required in non-interactive
> mode` → `Service "OpenConnect1": unexpectedly stopped`, looping. The server is fine; the
> client just can't pick a group. Set `authgroup` to a group the VPN user belongs to
> (`all` is `default_group` here).

### Diagnosing "it won't connect"

Read Keenetic's `show log`, not the server — anylink stays quiet pre-auth:

- `Connected to HTTPS … TLS1.3` then `User input required` → missing/`wrong authgroup`.
- TLS never connects / `failed to resolve` → router DNS or the cloud firewall (confirm the
  port is open from outside first: `nc -vz <node> 4443`).
- `Login failed` after the form → wrong VPN password or the user isn't in that group.
- **Connects, then drops every ~35s** (`read tcp …4443→…: i/o timeout` + `link_dtls EOF`
  in the *anylink* log, looping) → **tunnel MTU too high** (see below), not auth/DPI.

## Tunnel MTU — the ~35s-disconnect trap

Symptom: auth succeeds, IP is assigned, tunnel comes up — then **dies after ~35s**
(`cstp_dpd`) and reconnects in a loop. The anylink log shows both channels timing out at
once (`i/o timeout` on CSTP + `EOF` on DTLS) = the client went silent, because full-size
data/DPD packets are being **blackholed** by a path MTU lower than the tunnel MTU.

The client's WAN here is **PPPoE (1492)**; CSTP (TCP+TLS) overhead eats ~110 bytes →
real path MTU through the tunnel is **~1382**. With `mtu = 1400` in `server.toml`, packets
of 1383–1400 vanish silently (PMTUD doesn't cross the encrypted tunnel cleanly) → DPD
can't confirm liveness → drop. Set **`mtu = 1300`** (safe margin under 1382), and relax
DPD for the throttled RU→US path: **`cstp_dpd`/`mobile_dpd = 90`** (default 30/60 is too
aggressive when the foreign leg is lossy).

Measure the real ceiling from a device behind the router (ping the tunnel gateway with
DF set, increasing size — the router returns `frag needed and DF set (MTU NNNN)` at the
limit):

```bash
ping -D -s 1272 10.99.99.1     # 1300-byte packet — passes
ping -D -s 1372 10.99.99.1     # 1400-byte packet — "frag needed ... (MTU 1382)"
```

Then keep the anylink `mtu` comfortably below that number. (ICMP may show loss even at a
passing size — it's deprioritized on the foreign leg; the real test is whether the TCP
session survives past the old ~35s mark.)
