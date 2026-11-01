#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../CONFIG.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
id="tunnel_reviewabcdef1234"
key="sk-review-dummy-1234567890"
pass=0
good() {
  if ! bridge_read_desktop_config "$tmp/test.txt"; then echo "[FAIL] $1" >&2;exit 1;fi
  [[ "$BRIDGE_TUNNEL_ID" == "$id" && "$BRIDGE_RUNTIME_KEY" == "$key" ]] || { echo "[FAIL] values in $1" >&2;exit 1; }
  pass=$((pass+1))
}
bad() {
  if bridge_read_desktop_config "$tmp/test.txt" >/dev/null 2>&1; then echo "[FAIL] unexpectedly accepted $1" >&2;exit 1;fi
  pass=$((pass+1))
}
printf 'TunnelId:%s,ApiKey:%s' "$id" "$key" > "$tmp/test.txt"
good 'no final newline'
printf 'TunnelId:%s\nApiKey:%s\n' "$id" "$key" > "$tmp/test.txt"
good 'two lines'
printf '\xef\xbb\xbfTunnelId:%s,ApiKey:%s' "$id" "$key" > "$tmp/test.txt"
good 'UTF8 BOM'
printf 'TunnelId: %s ,ApiKey: %s  \n' "$id" "$key" > "$tmp/test.txt"
good 'spaces'
printf 'TunnelId:%s\r\nApiKey:%s\r\n' "$id" "$key" > "$tmp/test.txt"
good 'CRLF'
printf 'TunnelId:,TunnelId:%s,ApiKey:%s\n' "$id" "$key" > "$tmp/test.txt"
bad 'empty duplicate ID'
printf 'TunnelId:%s,ApiKey:,ApiKey:%s\n' "$id" "$key" > "$tmp/test.txt"
bad 'empty duplicate key'
printf '\xff\xfeT\x00u\x00n\x00n\x00e\x00l\x00I\x00d\x00:\x00' > "$tmp/test.txt"
bad 'UTF16'
printf 'TunnelId:%s,ApiKey:\n' "$id" > "$tmp/test.txt"
bad 'empty key'
printf 'TunnelId:%s,ApiKey:%s\nOther:no\n' "$id" "$key" > "$tmp/test.txt"
bad 'unknown field'
echo "PASS: Mac config cases $pass/10"
