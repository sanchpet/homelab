# Runbook: MTU / PMTUD blackhole to the cluster API (large transfers stall)

> Status: **stub / living** — diagnosis confirmed, fix not yet selected/applied.
> First written 2026-06-14 while bootstrapping Flux to `ips-usa-vps-2` (RU→US path).

## Symptom

- `kubectl get nodes` / small calls: instant (~0.5 s). ✅
- `flux bootstrap`, Freelens, `kubectl get --raw /openapi/v2` (≈567 KB): **stall ~45 s
  then `http2: client connection lost` / `context canceled` / `Internal Server Error`**. ❌
- A working cluster on the same laptop (different network path) is fine.

Signature: **small requests pass, large/streaming responses fail.** Classic MTU /
Path-MTU-Discovery (PMTUD) blackhole.

## Diagnosis (reproducible)

1. Confirm large transfer fails while small ones pass:
   ```bash
   kubectl get nodes >/dev/null                 # fast
   time kubectl get --raw /openapi/v2 | wc -c   # stalls ~45s → drops
   ```
2. Probe path MTU with don't-fragment pings (macOS):
   ```bash
   SRV=<api-ip>
   for s in 1464 1465 1472; do
     printf "MTU %s: " $((s+28))
     ping -c1 -D -s $s -t2 $SRV >/dev/null 2>&1 && echo OK || echo FAIL
   done
   ```
   Observed: **MTU 1492 OK, 1493+ FAIL → path MTU = 1492.**
3. Confirm the egress path & local interface are 1500 (reduction is upstream, not local):
   ```bash
   route -n get <api-ip> | grep -E 'interface:|gateway:'   # en0, home gw
   ifconfig en0 | grep mtu                                 # 1500
   ```

## Root cause (CONFIRMED — corrected from the first hypothesis)

> The first draft blamed the RU→US path (ICMP filtering). **Measurement disproved that.**
> It is the **local home link**, affecting all large transfers — not the cluster.

- **Path MTU = 1492 to *every* destination** (cluster, github, google, yandex) →
  `1500 − 8` = **home PPPoE link** (confirmed: static IP delivered over PPPoE).
- **PMTUD is broken on this link**: the router does not MSS-clamp and ICMP
  "fragmentation needed" doesn't make it back, so TCP keeps sending full 1500-byte
  segments (MSS 1460) which silently drop. Small responses fit under 1492 → fine.
- **Not cluster- or path-specific:** a 10 MB Cloudflare download *also* blackholes
  (24 KB in 25 s, ~1 kB/s) with the cluster idle. Any sustained large inbound transfer
  stalls.
- **Why it usually goes unnoticed:** an always-on VPN (v2RayTun / WireGuard are
  configured) tunnels traffic with its own MTU and masks the broken PMTUD. Both were
  *disconnected* during diagnosis → the raw link was exposed and large transfers stalled.
  The RU cluster "working in Freelens" was most likely accessed with the VPN on.

### Evidence

```
ping -D -s: 1492 OK / 1493 FAIL  → to cluster, github, google, yandex (all 1492)
cloudflare 10MB:  24 KB / 25 s, ~1 kB/s  → blackhole (not the cluster!)
kubectl get --raw /openapi/v2:  stalls → timeout
small calls (get nodes): instant
VPN: v2RayTun + WireGuard both Disconnected during the test; IPv4 default via en0
```

## How MSS clamping fixes it

- **MSS** (advertised in the TCP SYN) tells the peer the max segment it may send.
  MSS = MTU − 40. At 1500 both sides advertise 1460 → 1500-byte packets → exceed 1492.
- **Clamping** rewrites MSS in SYNs to e.g. 1452 → segments fit 1492 → no reliance on
  (broken) PMTUD.
- **Direction caveat:** on an endpoint host, `iptables -t mangle TCPMSS` is only valid
  in OUTPUT/POSTROUTING → it clamps the host's *outgoing* SYN/SYN-ACK, i.e. only the
  peer→host direction. The stalling `/openapi` download is **server→laptop**, whose size
  is governed by the **laptop's advertised MSS**. So a server-side iptables clamp alone
  does NOT fix this download. Use one of the fixes below instead.

## Candidate fixes (ranked)

The fix is **local** (the home link), not server-side. Ranked:

| Fix | Where | Effect | Trade-off |
|-----|-------|--------|-----------|
| MSS clamp on the home router (PPPoE WAN: "clamp MSS to MTU") or set WAN MTU 1492 | home router | global — every device, the proper fix | router admin access |
| Set laptop MTU to 1492 (System Settings → Network → en0 → Hardware → MTU → 1492) | client | laptop sends/accepts ≤1492; correct value for a PPPoE line | per-device; `ifconfig` change resets on reboot — set it in network settings to persist |
| Keep an MTU-aware VPN on (v2RayTun / WireGuard) | client | tunnel handles MTU → masks the problem | not a fix; and you may not want a VPN to manage the cluster |

Server-side (route `advmss`, lowering node MTU) is **not** the right lever here, since
every destination is affected — the bottleneck is the laptop's link, not any one server.

**Quick confirmation test** (reversible, needs sudo password):
```bash
sudo ifconfig en0 mtu 1492
curl -o /dev/null -w '%{speed_download} B/s\n' "https://speed.cloudflare.com/__down?bytes=5000000"
sudo ifconfig en0 mtu 1500   # revert
```
Full speed at 1492 → confirmed.

## Relevance to the VPN work (WP-040 Ф2)

This is the **same MTU class of bug** that bites OpenConnect/WireGuard. anylink/3x-ui
over a 1492 path + tunnel overhead must size their MTU/MSS accordingly, or VPN clients
will see the same "small ok, large stalls" behaviour. Fixing the path MSS now pays off
twice.

## TODO before marking this runbook done

- [x] Determine home vs path: PMTU 1492 to *all* destinations + Cloudflare 10MB also
      blackholes → **home PPPoE link**, confirmed.
- [ ] Run the `en0 mtu 1492` confirmation test (needs sudo) → expect full speed.
- [ ] Apply a permanent fix (router MSS-clamp preferred; or laptop MTU 1492 in settings).
- [ ] If router MSS-clamp chosen → note router model/setting here.

> The MSS-clamp **direction caveat** above still matters for the VPN work (Ф2): when
> anylink/WireGuard runs *on the node*, MTU/MSS must be sized for clients on similarly
> broken links. Keep this runbook linked from the VPN setup.
