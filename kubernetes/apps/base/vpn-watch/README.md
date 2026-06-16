# vpn-watch

Out-of-band reachability monitor for the VLESS/Reality VPN endpoints, run **from inside
RU** so it sees what offshore monitors can't: the DPI throttle on the RU→offshore path.

## Why a separate RU cluster

The VPN endpoints live on the offshore clusters (`ips-ger-vps`, `ips-usa-vps-2`). DPI is
applied at the RU border, so a probe must sit **inside RU** to observe the real failure.
`vpn-watch` therefore runs only on `sweb-ru-vps` and points xray-checker's subscription at
the ger+usa inbounds — probing exactly the path that gets throttled.

## Pieces (one app-template HelmRelease, four controllers)

| Controller | Role | Notes |
|------------|------|-------|
| `xray-checker` | probe each endpoint through Xray Core | method `ip` verifies exit IP through the tunnel; `/config/{stableId}` → 200/503 |
| `uptime-kuma` | poll `/config`, de-bounce, alert, status page | notifications: ntfy + SMS |
| `ntfy` | self-hosted push to phones | reachable from RU without VPN |
| `deadman` (cronjob) | relay-ping healthchecks.io while prober answers | node/cluster death → off-cluster alert |

Community-first: xray-checker / uptime-kuma / ntfy are upstream images wrapped by the
repo-standard bjw-s `app-template`; no hand-rolled controllers.

## Failure modes & who catches them

| Failure | Caught by |
|---------|-----------|
| Endpoint node down | xray-checker → 503 → Uptime Kuma → ntfy+SMS |
| **DPI blocks the protocol** (main) | xray-checker `ip`: fetch through tunnel fails → 503 |
| Endpoint egress dead | same (exit IP mismatch) |
| Prober / whole k3s dead | deadman stops pinging → **healthchecks.io** (off-cluster) |

Limitation: datacenter DPI on this node ≠ residential/mobile DPI. A second probe on a
home device (same subscription) is the later add for residential truth.

## Cluster overlay provides

- `secret.sops.yaml` — `SUBSCRIPTION_URL` (3x-ui sub) + `HC_PING_URL` (healthchecks).
- `httproute.yaml` — `ntfy.*` and `status.*` hostnames via the cluster Gateway.

## Next phase (separate PR)

Observability-grade alerting on metrics: scrape `xray-checker:2112/metrics` into the
planned **VictoriaMetrics** cluster (or `METRICS_PUSH_URL` push) → vmalert. This release
is unaffected.
