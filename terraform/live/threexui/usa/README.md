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

Inbound id is `1`. Provider import IDs: `threexui_inbound` ← `<inbound_id>`;
`threexui_inbound_client` ← `<inbound_id>:<client_uuid>`. During onboarding `subscription`
is `null` and `manage_panel_user = false`, so only the inbound + the 9 clients are imported.

Client UUIDs are VLESS credentials — they are NOT stored in this repo. Generate the import
commands from the live panel at runtime instead.

Prereqs: tunnel up; `secrets.sops.yaml` created (panel's current username/password,
`base_path: /`); then `terragrunt init`.

Save the inbounds list JSON (browser → open `http://localhost:2053/panel/api/inbounds/list`)
to `/tmp/usa-inbounds.json`, then generate + review the import commands:

```sh
jq -r '.obj[] | .id as $i
  | "terragrunt import '\''threexui_inbound.this[\"reality\"]'\'' \($i)"
  , (.clientStats[] | "terragrunt import '\''threexui_inbound_client.this[\"\(.email)\"]'\'' \($i):\(.uuid)")' \
  /tmp/usa-inbounds.json
```

Run the emitted commands (inbound + one per existing client).

Then `terragrunt plan` and review carefully:
- **Expected (intended alignment, safe in-place):** inbound `remark "" → "vless-reality-usa"`,
  `sniffing.enabled false → true` (module standard, same as ger).
- **MUST show no change (else STOP, do not apply):** reality `private_key` / `short_ids`
  (omitted in config → relied on as panel-managed/Computed, like ger); each client's `flow`
  (`xtls-rprx-vision`). If any of these would change/regenerate, pin them explicitly first.
- **No `destroy` / `replace`** on any client (would rotate UUIDs / break links).

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
