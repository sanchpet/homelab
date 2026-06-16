# 5. Apps — VPN workloads + 3x-ui panel-as-code

Once Flux is reconciling (doc 4), the `vpn` workloads come up from Git automatically:

| App | What | Config |
|-----|------|--------|
| `3x-ui` | Xray panel — VLESS/Reality inbound on host `:443` | `kubernetes/apps/base/3x-ui` + panel DB (see below) |
| `anylink` | OpenConnect/AnyConnect VPN | `apps/base/anylink` + per-cluster cert/config/SOPS secret |
| `gost` | TLS tunnel relay | `apps/base/gost` + per-cluster cert/SOPS secret |

`anylink`/`gost` secrets (`LINK_ADMIN_PASS`, …) are SOPS-encrypted in
`apps/clusters/<cluster>/<app>/secret.sops.yaml` and decrypted by Flux via the `sops-age`
Secret from doc 4 — nothing to do by hand.

## 3x-ui panel-as-code (Terraform)

The 3x-ui **panel config** (inbounds, clients, Reality keys) lives in the panel's SQLite
DB, not Git — unless you manage it with the `threexui-panel` module. The panel is
ClusterIP-only, so reach it over a tunnel first:

```bash
# VPN on:
kubectl --context <cluster> -n vpn port-forward svc/xui-panel 2053:2053
# VPN off (one SSH hop to the node, survives the DPI throttle):
ssh -L 2053:<xui-panel-clusterIP>:2053 sanchpet@<node>
```

Then declare the inbound + clients (state goes to S3 — doc 2):

```bash
cd terraform/live/threexui/<cluster>
cp secrets.sops.yaml.example secrets.sops.yaml   # panel admin user/pass + webBasePath
sops --encrypt --in-place secrets.sops.yaml      # needs the repo age key
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
# edit the inbound SNI + client emails in terragrunt.hcl, then:
terragrunt apply
```

Verify: `terragrunt plan` shows no drift, the inbound appears in the panel, and a client
connects via the generated VLESS link (build it from the `client_sub_ids` / `client_uuids`
outputs). Adding a panel = a new `terraform/live/threexui/<cluster>/`.

Done — the stack is up. Day-2 (upgrades, new clusters): the per-layer READMEs.
