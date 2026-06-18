# 6. sweb-ru-vps — RU monitoring vantage (vpn-watch)

A dedicated RU cluster whose only job is to watch the offshore VPN endpoints **from inside
RU**, where DPI actually bites. Offshore monitors report "up" while RU users are blocked;
this node closes that gap. See `kubernetes/apps/base/vpn-watch/README.md` for the app.

> Provider: SpaceWeb (sweb), region RU, type vps → cluster `sweb-ru-vps`,
> domain base `watcher.ru.sweb.sanch.pet`. This node runs **no Reality inbound** — it is a
> probe, not a VPN endpoint.

## Onboarding sequence (owner runs the applies — `apply self` rule)

1. **Provision + day-0 + hardening** (docs 1, 3): order the sweb RU VPS in the panel. The
   `ansible/inventory/sweb-ru-vps/` entry is already in this PR (it targets the DNS name
   `watcher.ru.sweb.sanch.pet`, not an IP — set the A record in step 3). Then `bootstrap.yml`
   (`-u root -k`) and the `common` + `hardening` roles. Forwarding/firewall as for any node.
2. **k3s** (doc 4): install via the `k3s.orchestration` collection, single-server.
3. **DNS:** point `ntfy.watcher.ru.sweb.sanch.pet` and `status.watcher.ru.sweb.sanch.pet` at the
   node IP (A records). Needed for cert-manager HTTP-01 on the `:80` Gateway listener.
4. **Flux bootstrap** (doc 4) — generates `clusters/sweb-ru-vps/flux-system/` and commits:
   ```bash
   flux bootstrap github \
     --owner=sanchpet --repository=homelab --branch=main \
     --path=./kubernetes/clusters/sweb-ru-vps --personal
   ```
5. **SOPS age key** on the node: create the `sops-age` Secret in `flux-system` from the
   repo age private key (same recipient as `.sops.yaml`; per-cluster key is an optional
   later hardening). Without it the `apps` Kustomization can't decrypt.
6. **The subscription secret:**
   ```bash
   cd kubernetes/apps/clusters/sweb-ru-vps/vpn-watch
   cp secret.sops.yaml.example secret.sops.yaml
   $EDITOR secret.sops.yaml          # SUBSCRIPTION_URL (ger+usa sub) + HC_PING_URL
   export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
   sops --encrypt --in-place secret.sops.yaml
   ```
   Commit the encrypted file (the `.example` stays as the template).

Once Flux reconciles: `infra-crds → infra-controllers → infra-configs → apps`. The
`vpn-watch` release comes up in `monitoring`.

## Image-pull egress (RU node) — through the German gost relay

Pulling `ghcr.io` / `docker.io` from RU hits the DPI blackhole, so containerd would hang in
`ImagePullBackOff`. Fix: route pulls through the **German gost relay** (the DPI-resistant TLS
proxy already running on `ips-ger-vps`), not a third-party mirror.

Mechanism (important distinctions):
- k3s embeds **containerd**, which honours `HTTP(S)_PROXY` from the k3s service env — set via
  `extra_service_envs` in this node's `group_vars`. **Not** `registries.yaml` (mirrors/auth)
  and **not** cri-o (k3s uses containerd).
- The relay is already a valid **HTTPS proxy** (real Let's Encrypt cert), and Go/containerd
  speak `https://` proxies directly — so we point straight at it, **no local gost client**.
  (Proof: the `curl -x 'https://gost...:7443'` one-liner in `apps/base/gost/README.md`.)
- No bootstrap paradox: the relay lives on the *ger* cluster (already up), not on this node.

The password is injected from ansible-vault as `gost_proxy_pass` (same value as the
gost-config SOPS secret, user `sanchpet`) — never committed. Verify the relay before
installing k3s:

```bash
curl -x 'https://sanchpet:PASS@gost.vps.ger.ips.sanch.pet:7443' https://api.ipify.org
# -> the German VPS IP = egress works
```

## Uptime Kuma — one manual step (state is in SQLite, not declarative)

1. Open `https://status.watcher.ru.sweb.sanch.pet`, create the admin.
2. Per endpoint `stableId` (`/api/v1/proxies` on xray-checker) add an HTTP(s) monitor:
   `http://xray-checker.monitoring:2112/config/{stableId}`, accept `200`, interval 60s,
   retries 3.
3. Notifications: `ntfy` (`https://ntfy.watcher.ru.sweb.sanch.pet`, topic `vpn-alerts`) **and**
   an SMS provider (RU-reachable). Attach both to every monitor.
4. ntfy is `deny-all` → mint an access token for Kuma (publish) and read access for the
   friends' app subscriptions.

## Smoke-test (closed-loop)

- Disable one ger/usa inbound in 3x-ui → within ~5 min the monitor goes red → ntfy **and**
  SMS arrive → re-enable → recovery notice.
- `kubectl -n monitoring scale deploy/vpn-watch-uptime-kuma --replicas=0` is not the test;
  instead `scale deploy/vpn-watch-xray-checker --replicas=0` → deadman stops → healthchecks.io
  alerts off-cluster. Restore to `1`.

Record the actual detection times — that is the evidence the promise holds.
