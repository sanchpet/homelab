#!/usr/bin/env bash
# Sourced by mise ([env]._.source in terraform/mise.toml) on entering terraform/ — exports a
# fresh SpaceWeb token as SWEB_TOKEN for the sweb terraform provider. SpaceWeb tokens are
# short-lived with no refresh flow, so we mint fresh on each activation (no cache) rather than
# risk a stale token mid-apply. No-ops silently if the sweb CLI isn't installed/configured
# (non-sweb work in terraform/ isn't disturbed).
#
# Like yc-token.sh, mise runs this in a bare `bash --noprofile` where the mise tool PATH (and
# thus the `sweb` shim) isn't set up yet — hence the `mise x -- sweb` fallback.
__sweb_create_token() {
  if command -v sweb >/dev/null 2>&1; then
    sweb token 2>/dev/null
  elif command -v mise >/dev/null 2>&1; then
    mise x -- sweb token 2>/dev/null
  fi
}

__sweb_tok="$(__sweb_create_token)"
[ -n "$__sweb_tok" ] && export SWEB_TOKEN="$__sweb_tok"
unset __sweb_tok
unset -f __sweb_create_token 2>/dev/null
