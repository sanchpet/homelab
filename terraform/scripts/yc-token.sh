#!/usr/bin/env bash
# Sourced by mise ([env]._.source in terraform/mise.toml) on entering terraform/ —
# exports a Yandex IAM token as YC_TOKEN for the terraform/ units (the yandex provider
# reads it). IAM tokens live ~12h, so it's cached ~11h to avoid calling the API on every
# shell prompt. No-ops silently if yc isn't available/logged in (non-Yandex work in
# terraform/ isn't disturbed).
#
# Note: mise runs this in a bare `bash --noprofile` where the mise tool PATH (and thus the
# `yc` shim) isn't set up yet — hence the `mise x -- yc` fallback. The cache read is OUTSIDE
# the fetch guard so an existing token is exported even when yc can't be invoked here.
__yc_cache="${XDG_CACHE_HOME:-$HOME/.cache}/yc-iam-token"

__yc_create_token() {
  if command -v yc >/dev/null 2>&1; then
    yc iam create-token 2>/dev/null
  elif command -v mise >/dev/null 2>&1; then
    mise x -- yc iam create-token 2>/dev/null
  fi
}

if [ ! -s "$__yc_cache" ] || [ -n "$(find "$__yc_cache" -mmin +660 2>/dev/null)" ]; then
  __yc_tok="$(__yc_create_token)"
  [ -n "$__yc_tok" ] && (umask 077; printf '%s' "$__yc_tok" >"$__yc_cache")
  unset __yc_tok
fi

[ -s "$__yc_cache" ] && export YC_TOKEN="$(cat "$__yc_cache")"
unset __yc_cache
unset -f __yc_create_token 2>/dev/null
