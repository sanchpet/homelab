#!/usr/bin/env bash
# Sourced by mise ([env]._.source in terraform/mise.toml) on entering terraform/ — exports a
# SpaceWeb token as SWEB_TOKEN for the sweb terraform provider.
#
# CACHED (~2h): the getToken endpoint is rate-limited (`-32400 Превышено число попыток
# операции`), so minting on every `cd` trips the limit and stalls the shell. We mint at most
# once every couple of hours and read the cache the rest of the time. The cache read is
# OUTSIDE the fetch guard so an existing token is exported even when the CLI can't be invoked
# here.
#
# Like yc-token.sh, mise runs this in a bare `bash --noprofile` where the mise tool PATH (and
# thus the `sweb` shim) isn't set up yet — hence the `mise x -- sweb` fallback. No-ops
# silently if the CLI isn't installed/configured (non-sweb work in terraform/ isn't disturbed).
__sweb_cache="${XDG_CACHE_HOME:-$HOME/.cache}/sweb-token"

__sweb_create_token() {
  if command -v sweb >/dev/null 2>&1; then
    sweb token 2>/dev/null
  elif command -v mise >/dev/null 2>&1; then
    mise x -- sweb token 2>/dev/null
  fi
}

if [ ! -s "$__sweb_cache" ] || [ -n "$(find "$__sweb_cache" -mmin +120 2>/dev/null)" ]; then
  __sweb_tok="$(__sweb_create_token)"
  # Only cache a plausible token — never the empty output of a rate-limit/error.
  [ -n "$__sweb_tok" ] && (umask 077; printf '%s' "$__sweb_tok" >"$__sweb_cache")
  unset __sweb_tok
fi

[ -s "$__sweb_cache" ] && export SWEB_TOKEN="$(cat "$__sweb_cache")"
unset __sweb_cache
unset -f __sweb_create_token 2>/dev/null
