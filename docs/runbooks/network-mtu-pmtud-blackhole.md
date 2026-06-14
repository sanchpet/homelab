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

## Root cause

- **Path MTU = 1492** → `1500 − 8` = **PPPoE** somewhere on the path (most likely the
  home ISP link). Not the local NIC (en0 is 1500, traffic goes direct via the router).
- **PMTUD is blackholed**: the RU→US path filters ICMP "fragmentation needed", so TCP
  never learns the path is 1492. It keeps sending full 1500-byte segments (MSS 1460),
  which silently drop. Small responses fit one sub-1492 packet → unaffected.
- **Why another (RU) cluster works on the same laptop:** its path either passes ICMP
  (PMTUD works → TCP adapts to 1492) or its provider clamps MSS. The US path does
  neither → the benign 1492 becomes a blackhole.

> **Open question (TODO):** is 1492 the home PPPoE link (shared by all destinations) or
> a reduction specific to the US path? Resolve by probing PMTU to the working RU
> cluster: same `ping -D -s`. 1492 there too → home link; 1500 → US-path reduction.

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

| Fix | Where | Effect | Trade-off |
|-----|-------|--------|-----------|
| MSS clamp on the home router (PPPoE WAN: "clamp MSS to MTU") | home router | global, all connections — the proper fix | router admin access |
| Set laptop MTU to 1492 (`sudo ifconfig en0 mtu 1492`) | client | laptop advertises MSS 1452 → server sends ≤1452; correct value for a PPPoE line | all laptop traffic; resets on reboot (make permanent in network settings) |
| Route `advmss`/`mtu` on the server (`ip route change default ... advmss 1452`) | server | server caps sends to this path | per-server; persist via systemd-networkd / ansible |
| Bootstrap Flux **from the node** (API on 127.0.0.1) | — | sidesteps entirely for the task; Flux runs in-cluster after | doesn't fix laptop→cluster management |

**Quick confirmation test** (reversible): `sudo ifconfig en0 mtu 1492`, retry
`kubectl get --raw /openapi/v2 | wc -c`. Works → MTU root cause confirmed. Revert with
`sudo ifconfig en0 mtu 1500`.

## Relevance to the VPN work (WP-040 Ф2)

This is the **same MTU class of bug** that bites OpenConnect/WireGuard. anylink/3x-ui
over a 1492 path + tunnel overhead must size their MTU/MSS accordingly, or VPN clients
will see the same "small ok, large stalls" behaviour. Fixing the path MSS now pays off
twice.

## TODO before marking this runbook done

- [ ] Probe PMTU to the RU cluster → home vs US-path question.
- [ ] Pick a fix, apply, confirm `/openapi/v2` downloads cleanly.
- [ ] If router MSS-clamp chosen → note router model/setting here.
- [ ] If a server/route fix → codify in ansible (e.g. a `network-tune` role) for IaC.
