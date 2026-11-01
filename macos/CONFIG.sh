#!/bin/bash
# Shared macOS Desktop TXT parser. Source from CONNECT.sh and AUTOSTART.sh.
# Exports nothing and never prints credentials.
bridge_read_desktop_config() {
  local config="$1" field value prefix seen_id=0 seen_key=0 first=1
  BRIDGE_TUNNEL_ID=''
  BRIDGE_RUNTIME_KEY=''
  [[ -f "$config" ]] || { echo '[MAC CONFIG ERROR] Credential TXT not found on this Mac Desktop.' >&2; return 1; }
  [[ "$(wc -c < "$config")" -le 8192 ]] || { echo '[MAC CONFIG ERROR] TXT exceeds 8 KiB.' >&2; return 1; }
  prefix="$(LC_ALL=C head -c 3 "$config" | od -An -tx1 | tr -d ' \n')"
  case "$prefix" in
    fffe*|feff*) echo '[MAC CONFIG ERROR] UTF-16 unsupported. Save as UTF-8 plain text (not RTF).' >&2;return 1 ;;
  esac
  while IFS= read -r field || [[ -n "$field" ]]; do
    if [[ "$first" -eq 1 ]]; then
      field="${field#$'\xEF\xBB\xBF'}"
      first=0
    fi
    field="${field#"${field%%[![:space:]]*}"}"
    field="${field%"${field##*[![:space:]]}"}"
    [[ -z "$field" ]] && continue
    case "$field" in
      TunnelId:*)
        [[ "$seen_id" -eq 0 ]] || { echo '[MAC CONFIG ERROR] Duplicate TunnelId.' >&2;return 1; }
        seen_id=1
        value="${field#TunnelId:}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        BRIDGE_TUNNEL_ID="$value"
        ;;
      ApiKey:*)
        [[ "$seen_key" -eq 0 ]] || { echo '[MAC CONFIG ERROR] Duplicate ApiKey.' >&2;return 1; }
        seen_key=1
        value="${field#ApiKey:}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        BRIDGE_RUNTIME_KEY="$value"
        ;;
      *) echo '[MAC CONFIG ERROR] Invalid TXT. Use UTF-8 plain text: TunnelId:tunnel_...,ApiKey:sk-... .' >&2;return 1 ;;
    esac
  done < <(tr '\r\n,' '\n\n\n' < "$config")
  [[ "$seen_id" -eq 1 && "$BRIDGE_TUNNEL_ID" =~ ^tunnel_[A-Za-z0-9_-]{8,}$ ]] || { echo '[MAC CONFIG ERROR] Invalid/missing TunnelId.' >&2; return 1; }
  [[ "$seen_key" -eq 1 && "${#BRIDGE_RUNTIME_KEY}" -ge 12 &&
    "${#BRIDGE_RUNTIME_KEY}" -le 512 && "$BRIDGE_RUNTIME_KEY" =~ ^[A-Za-z0-9._-]+$ ]] ||
    { echo '[MAC CONFIG ERROR] Invalid/missing runtime ApiKey (not printed).' >&2; return 1; }
}
