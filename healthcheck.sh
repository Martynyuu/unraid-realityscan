#!/usr/bin/env bash
# Docker HEALTHCHECK. Only MODE=rsnode is checked: read the bearer over loopback, then
# GET /node/status with it (without the bearer RSNode answers 401, which curl -f treats as failure).
set -euo pipefail
mode="$(cat "${STATE_DIR:-/tmp/rsnode}/mode" 2>/dev/null || echo "${MODE:-rsnode}")"
[ "$mode" = rsnode ] || exit 0
port="${RSNODE_PORT:-30010}"
scheme=http
curl_opts=(-fsS --max-time 5 -o /dev/null)
case " ${RSNODE_ARGS:-} " in *" -tlsKey "*) scheme=https; curl_opts+=(-k) ;; esac
token="$(rsnode-token)"
curl "${curl_opts[@]}" -H "Authorization: Bearer $token" "$scheme://127.0.0.1:$port/node/status"
