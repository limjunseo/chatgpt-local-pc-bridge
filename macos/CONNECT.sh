#!/bin/bash
# macOS-only local MCP tunnel. Does not touch any Windows components.
set -euo pipefail
umask 077
[[ "$(uname -s)" == "Darwin" ]] || { echo "[ERROR] macOS only."; exit 2; }
APP_DIR="$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac"
BIN="$APP_DIR/bin/tunnel-client"
MCP="$APP_DIR/local-mac-mcp.cjs"
WORKSPACE="$HOME/ChatGPTLocalFiles"
PROFILE="chatgpt-local-mac"
CONFIG="${MAC_BRIDGE_CONFIG:-$HOME/Desktop/codex_세팅연결.txt}"
AUTOSTART="$APP_DIR/AUTOSTART.sh"
fail() { printf '[MAC TUNNEL ERROR] %s\n' "$1" >&2; exit 1; }
[[ -x "$BIN" ]] || fail "Tunnel client missing; run macos/INSTALL.sh."
[[ -f "$MCP" && -d "$WORKSPACE" ]] || fail "Mac MCP/workspace missing; run macos/INSTALL.sh."
[[ -f "$CONFIG" ]] || fail "Desktop/codex_세팅연결.txt not found."
[[ "$(wc -c < "$CONFIG")" -le 8192 ]] || fail "Credential TXT is too large."
NODE="$(command -v node || true)"
[[ -n "$NODE" ]] || fail "Node.js missing."
[[ "$NODE" != *'"'* && "$MCP" != *'"'* ]] || fail "Unexpected quote in install path."
TUNNEL_ID=''
API_KEY=''
while IFS= read -r field; do
  field="${field#"${field%%[![:space:]]*}"}"
  field="${field%"${field##*[![:space:]]}"}"
  [[ -z "$field" ]] && continue
  case "$field" in
    TunnelId:*)
      [[ -z "$TUNNEL_ID" ]] || fail "Duplicate TunnelId."
      TUNNEL_ID="${field#TunnelId:}"
      ;;
    ApiKey:*)
      [[ -z "$API_KEY" ]] || fail "Duplicate ApiKey."
      API_KEY="${field#ApiKey:}"
      ;;
    *) fail "Invalid TXT. Use TunnelId:tunnel_...,ApiKey:sk-... (never printed)." ;;
  esac
done < <(tr '\r\n,' '\n\n\n' < "$CONFIG")
[[ "$TUNNEL_ID" =~ ^tunnel_[A-Za-z0-9_-]{8,}$ ]] || fail "Invalid TunnelId."
[[ "${#API_KEY}" -ge 12 && "${#API_KEY}" -le 512 && "$API_KEY" =~ ^[A-Za-z0-9._-]+$ ]] || fail "Invalid runtime key (not printed)."
export LOCAL_PC_ROOT="$WORKSPACE"
export PATH="$(dirname "$NODE"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export CONTROL_PLANE_API_KEY="$API_KEY"
unset API_KEY
trap 'unset CONTROL_PLANE_API_KEY' EXIT
printf '[MAC TUNNEL] Configuring local MCP with your existing tunnel.\n'
"$BIN" init --force --sample sample_mcp_stdio_local \
  --profile "$PROFILE" --tunnel-id "$TUNNEL_ID" \
  --mcp-command "\"$NODE\" \"$MCP\""
printf '[MAC TUNNEL] Checking official doctor preflight.\n'
"$BIN" doctor --profile "$PROFILE" --explain
printf '\n[MAC TUNNEL] Doctor passed. Login autostart is optional.\n'
if [[ -f "$AUTOSTART" ]]; then
  printf 'Enable tunnel at each login to this Mac account? (y/N): '
  read -r answer
  if [[ "$answer" == [yY] ]]; then bash "$AUTOSTART" enable; fi
fi
printf '[MAC TUNNEL] Starting tunnel. Keep Terminal open.\n'
printf '[MAC TUNNEL] ChatGPT Plugins > Add custom MCP server > Tunnel > Authentication: None.\n'
"$BIN" run --profile "$PROFILE"
