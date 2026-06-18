# live/threexui/usa — onboarding the USA 3x-ui panel into Terraform

The USA panel (cluster `ips-usa-vps-2`) pre-exists with live clients. Unlike `ger/` (which
Terraform created greenfield), this unit **imports** the existing panel so the first apply is
a no-op. This README is the import + parity runbook. Mirror of the `ger/` unit otherwise.

## Prerequisites

- Tunnel to the ClusterIP-only panel so `http://localhost:2053` reaches it (see header of
  `terragrunt.hcl`): `kubectl port-forward -n vpn svc/xui-panel 2053:2053` (VPN on) or
  `ssh -L 2053:<clusterIP>:2053 <usa-node>` (VPN off).
- age key locally (`SOPS_AGE_KEY_FILE` or `~/.config/sops/age/keys.txt`).
- `secrets.sops.yaml` created from the example with the panel's CURRENT admin creds.

## §Enumerate (read the live panel)

Log in and list inbounds + clients (the source of truth for import values and the parity diff):

```sh
# login → cookie
curl -sc /tmp/xui.cookie -d 'username=<admin>&password=<pass>' http://localhost:2053/<base_path>/login
# inbounds (incl. reality settings + clients)
curl -sb /tmp/xui.cookie http://localhost:2053/<base_path>/panel/api/inbounds/list | jq .
```

From the output capture, per inbound: `id`, `port`, `remark`, and from
`streamSettings.realitySettings`: `dest`/`target`, `serverNames`, `privateKey`, `shortIds`.
Per client (in `settings.clients`): `email`, `id` (uuid), `subId`, `flow`.

## §Import

1. Fill `terragrunt.hcl` `inbounds.reality` with the real values from §Enumerate, including
   `reality_private_key` and `reality_short_ids` (else apply regenerates them and breaks clients).
2. List every existing client in `clients.sops.yaml` (handle = panel `email`).
3. Write `import` blocks (Terraform >= 1.5) for the existing resources, then plan to a no-op.
   Resource addresses to import (IDs per the `batonogov/threexui` provider — confirm format):
   - `threexui_inbound.this["reality"]`
   - `threexui_inbound_client.this["<handle>"]` (one per existing client)
   - `threexui_panel_subscription.settings[0]`
   - `random_string.sub_path[0]` (the existing sub path — import or accept a one-time set)
   - `threexui_panel_user.admin[0]` only if `manage_panel_user = true`
4. `terragrunt plan` → iterate `terragrunt.hcl` until the plan is **empty** (no-op).

## §Add the cudy-openwrt client

After import is a clean no-op, add the client to BOTH panels (this unit and `../ger/`):

```sh
sops clients.sops.yaml   # add the cudy-openwrt entry (see clients.sops.yaml.example)
terragrunt apply         # creates only the new client
```

Then grab its `vless://` link from the panel (client → QR/URL) for the OpenWrt router (WP-045).

## §Parity audit (USA vs GER)

Compare client handles present on each panel and list what USA lacks vs GER:

```sh
sops -d ../ger/clients.sops.yaml | yq '.clients' | yq 'keys'   # GER handles
sops -d ./clients.sops.yaml      | yq '.clients' | yq 'keys'   # USA handles
# diff the two sets → the missing-on-USA set is the parity gap
```

Decide which of the GER-only clients should also exist on USA, add them to
`clients.sops.yaml`, and `apply`.
