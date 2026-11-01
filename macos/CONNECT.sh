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
[[ -f "$APP_DIR/CONFIG.sh" ]] || fail "Shared config parser missing. Reinstall updated Mac bundle."
# Avoid creating a second stdio tunnel client while a login LaunchAgent is already running.
LABEL="com.limjunseo.chatgpt-local-mac-bridge.tunnel"
if /bin/launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -Eq '^[[:space:]]*state = running'; then
  printf '[MAC TUNNEL] Mac login LaunchAgent is already running. No second tunnel was started.\n'
  exit 0
fi
if [[ ! -f "$CONFIG" ]]; then
  if [[ -f "$APP_DIR/tunnel-id.txt" && -f "$AUTOSTART" ]]; then
    printf '[MAC TUNNEL] Desktop TXT is absent. Attempting manual reconnect with Keychain.\n'
    exec bash "$AUTOSTART" run
  fi
  fail "Desktop TXT is missing and no configured Keychain reconnect is available."
fi
# shellcheck source=CONFIG.sh
source "$APP_DIR/CONFIG.sh"
bridge_read_desktop_config "$CONFIG" || fail "Credential TXT is not valid UTF-8 plain text."
NODE="$(command -v node || true)"
[[ -n "$NODE" ]] || fail "Node.js missing."
[[ "$NODE" != *'"'* && "$MCP" != *'"'* ]] || fail "Unexpected quote in install path."
TUNNEL_ID="$BRIDGE_TUNNEL_ID"
export CONTROL_PLANE_API_KEY="$BRIDGE_RUNTIME_KEY"
unset BRIDGE_RUNTIME_KEY
export LOCAL_PC_ROOT="$WORKSPACE"
export PATH="$(dirname "$NODE"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
trap 'unset CONTROL_PLANE_API_KEY' EXIT
printf '[MAC TUNNEL] Configuring local MCP with your existing tunnel.\n'
"$BIN" init --force --sample sample_mcp_stdio_local \
  --profile "$PROFILE" --tunnel-id "$TUNNEL_ID" \
  --mcp-command "\"$NODE\" \"$MCP\""
printf '[MAC TUNNEL] Checking official doctor preflight.\n'
"$BIN" doctor --profile "$PROFILE" --explain
printf '%s\n' "$TUNNEL_ID" > "$APP_DIR/tunnel-id.txt"
chmod 600 "$APP_DIR/tunnel-id.txt"
printf '\n[MAC TUNNEL] Doctor passed. Login autostart is optional.\n'
if [[ -f "$AUTOSTART" ]]; then
  printf 'Enable tunnel at each login to this Mac account? (y/N): '
  read -r answer
  if [[ "$answer" == [yY] ]]; then
    if bash "$AUTOSTART" enable; then
      printf '[MAC TUNNEL] Login auto-start registered. Continuing current manual connection.\n'
    else
      printf '[MAC TUNNEL] Login auto-start was declined or failed; continuing manual connection.\n'
    fi
  fi
fi
printf '[MAC TUNNEL] Starting tunnel. Keep Terminal open.\n'
printf '[MAC TUNNEL] ChatGPT Plugins > Add custom MCP server > Tunnel > Authentication: None.\n'
"$BIN" run --profile "$PROFILE"
