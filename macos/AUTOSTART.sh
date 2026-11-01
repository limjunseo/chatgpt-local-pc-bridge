#!/bin/bash
# Opt-in macOS login LaunchAgent. Independent of all Windows components.
set -euo pipefail
umask 077
[[ "$(uname -s)" == "Darwin" ]] || { echo "[ERROR] macOS only." >&2; exit 2; }
APP_DIR="$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac"
BIN="$APP_DIR/bin/tunnel-client"
MCP="$APP_DIR/local-mac-mcp.cjs"
PROFILE="chatgpt-local-mac"
ID_FILE="$APP_DIR/tunnel-id.txt"
CONFIG="${MAC_BRIDGE_CONFIG:-$HOME/Desktop/codex_세팅연결.txt}"
LABEL="com.limjunseo.chatgpt-local-mac-bridge.tunnel"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SERVICE="ChatGPTLocalMacBridgeRuntimeKey"
ACCOUNT="$(id -un)"
ACTION="${1:-status}"
fail() { printf '[MAC AUTO ERROR] %s\n' "$1" >&2; exit 1; }
note() { printf '[MAC AUTO] %s\n' "$1"; }
xml_escape() {
  sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}
read_txt() {
  [[ -f "$APP_DIR/CONFIG.sh" ]] || fail "Shared config parser missing. Reinstall updated Mac bundle."
  # shellcheck source=CONFIG.sh
  source "$APP_DIR/CONFIG.sh"
  bridge_read_desktop_config "$CONFIG" || fail "Credential TXT format invalid."
  ID="$BRIDGE_TUNNEL_ID"
  KEY="$BRIDGE_RUNTIME_KEY"
  unset BRIDGE_RUNTIME_KEY
}
case "$ACTION" in
  status)
    [[ -f "$PLIST" ]] && note "Login LaunchAgent file exists." || note "Login LaunchAgent not installed."
    [[ -f "$ID_FILE" ]] && note "Mac tunnel profile ID recorded." || note "Mac tunnel profile not configured."
    if /usr/bin/security find-generic-password -s "$SERVICE" -a "$ACCOUNT" >/dev/null 2>&1; then
      note "Runtime key exists in login Keychain."
    else
      note "Runtime key not in Keychain or access not granted."
    fi
    note "For current process state: launchctl print gui/$(id -u)/$LABEL"
    ;;
  enable)
    [[ -x "$BIN" && -f "$MCP" && -f "$ID_FILE" ]] || fail "First connect Mac tunnel successfully (CONNECT.sh)."
    read_txt
    [[ "$ID" = "$(cat "$ID_FILE")" ]] || fail "Desktop Tunnel ID differs from configured Mac profile."
    note "THIS ENABLES TUNNEL ACCESS EVERY TIME THIS MAC USER LOGS IN, EVEN WHEN CHATGPT IS CLOSED."
    printf 'Mac owner approves user-login automatic tunnel access? [y/N]: '
    read -r answer
    [[ "$answer" == [yY] ]] || { note 'No changes made.'; exit 2; }
    # Use /usr/bin/security -i and a stdin pipe: secrets never appear as OS command-line arguments.
    # Restrict key characters to avoid interactive security shell command injection.
    printf 'add-generic-password -a "%s" -s "%s" -U -w "%s"\nquit\n' \
      "$ACCOUNT" "$SERVICE" "$KEY" | /usr/bin/security -i >/dev/null 2>&1 || fail "Keychain write failed."
    confirmed="$(/usr/bin/security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null)" || fail "Keychain permission or item lookup failed."
    [[ "$confirmed" = "$KEY" ]] || fail "Keychain saved password did not match supplied runtime key."
    unset KEY confirmed
    mkdir -p "$HOME/Library/LaunchAgents" "$APP_DIR/logs"
    chmod 700 "$APP_DIR" "$APP_DIR/logs"
    runner="$APP_DIR/AUTOSTART.sh"
    log="$APP_DIR/logs/launchd.out.log"
    err="$APP_DIR/logs/launchd.err.log"
    # IMPORTANT: paths must begin immediately after <string>; a newline here breaks launchd.
    {
      printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
      printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      printf '%s\n' '<plist version="1.0"><dict>'
      printf '%s\n' '<key>Label</key><string>com.limjunseo.chatgpt-local-mac-bridge.tunnel</string>'
      printf '%s' '<key>ProgramArguments</key><array><string>/bin/bash</string><string>'
      printf '%s' "$runner" | xml_escape
      printf '%s\n' '</string><string>run</string></array>'
      printf '%s\n' '<key>RunAtLoad</key><true/>'
      printf '%s\n' '<key>KeepAlive</key><false/>'
      printf '%s' '<key>StandardOutPath</key><string>'
      printf '%s' "$log" | xml_escape
      printf '%s\n' '</string>'
      printf '%s' '<key>StandardErrorPath</key><string>'
      printf '%s' "$err" | xml_escape
      printf '%s\n' '</string>'
      printf '%s\n' '</dict></plist>'
    } > "$PLIST"
    chmod 600 "$PLIST"
    /usr/bin/plutil -lint -s "$PLIST" || fail "LaunchAgent plist validation failed."
    [[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy unavailable for field validation."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:1' "$PLIST")" = "$runner" &&
       "$(/usr/libexec/PlistBuddy -c 'Print :StandardOutPath' "$PLIST")" = "$log" &&
       "$(/usr/libexec/PlistBuddy -c 'Print :StandardErrorPath' "$PLIST")" = "$err" ]] ||
       fail "Generated LaunchAgent paths differ from expected values; refusing to claim setup succeeded."
    note "Login auto-start registered for NEXT login; current manual tunnel left running."
    note "Agent is user-visible in ~/Library/LaunchAgents, with logs under the Mac app folder."
    printf 'Remove plaintext Desktop TXT now? Recommended [y/N]: '
    read -r remove_answer
    if [[ "$remove_answer" == [yY] ]]; then
      rm -f "$CONFIG"
      note "Plaintext TXT removed (backups may still contain a copy)."
    else note "WARNING: plaintext API key TXT remains on Desktop."; fi
    ;;
  disable)
    printf 'Remove Mac user login auto-start AND Keychain runtime key? [y/N]: '
    read -r answer
    [[ "$answer" == [yY] ]] || { note 'No changes made.'; exit 2; }
    if [[ -f "$PLIST" ]]; then
      /bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
      rm -f "$PLIST"
    fi
    /usr/bin/security delete-generic-password -s "$SERVICE" -a "$ACCOUNT" >/dev/null 2>&1 || true
    note "Mac login autostart disabled. Close an independently running manual tunnel if needed."
    ;;
  run)
    [[ -x "$BIN" && -f "$MCP" && -f "$ID_FILE" ]] || fail "Mac MCP/tunnel missing."
    export LOCAL_PC_ROOT="$HOME/ChatGPTLocalFiles"
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
    export CONTROL_PLANE_API_KEY="$(/usr/bin/security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w)" || fail "Keychain not accessible after login."
    [[ -n "$CONTROL_PLANE_API_KEY" ]] || fail "Runtime key is empty."
    trap 'unset CONTROL_PLANE_API_KEY' EXIT
    note "Login auto-start: checking tunnel (no network port opened for inbound traffic)."
    for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
      if "$BIN" doctor --profile "$PROFILE" --explain; then break; fi
      if [[ "$attempt" -eq 12 ]]; then fail "Doctor failed 12 times; inspect key/network/permissions."; fi
      sleep 20
    done
    note "Doctor passed. Running Mac tunnel."
    "$BIN" run --profile "$PROFILE"
    ;;
  *) fail "Usage: bash AUTOSTART.sh enable|disable|status|run" ;;
esac
