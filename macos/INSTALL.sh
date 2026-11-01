#!/bin/bash
# macOS-only installation; does NOT install or change Windows scripts.
set -euo pipefail
umask 077
[[ "$(uname -s)" == "Darwin" ]] || { echo "[MAC INSTALL ERROR] macOS only." >&2; exit 2; }
APP_DIR="$HOME/Library/Application Support/ChatGPTLocalPCBridgeMac"
BIN_DIR="$APP_DIR/bin"
WORKSPACE="$HOME/ChatGPTLocalFiles"
RELEASE="v0.0.19"
case "$(uname -m)" in
  arm64)
    ARCH="arm64"
    TUNNEL_SHA="2243d024b77af8ee4b4ab7a1447949e5fc8d82bcd2d51b178927f2da9e47ecfd"
    ;;
  x86_64)
    ARCH="amd64"
    TUNNEL_SHA="dff97674c77cac59e6ab3d901e6cff50fb17a5784c01d8959d1f4adb3afdf4bf"
    ;;
  *) echo "[MAC INSTALL ERROR] Unsupported Mac architecture." >&2; exit 2 ;;
esac
fail() { printf '[MAC INSTALL ERROR] %s\n' "$1" >&2; exit 1; }
note() { printf '[MAC INSTALL] %s\n' "$1"; }
if [[ "${1:-}" == "--dry-run" ]]; then
  note "macOS architecture: $ARCH"
  note "Node: $(command -v node || echo missing)"
  note "Existing Mac app: $APP_DIR"
  note "Tunnel binary present: $(test -x "$BIN_DIR/tunnel-client" && echo yes || echo no)"
  note "Windows installers are not used or modified."
  exit 0
fi
note "This installs a separate macOS bridge into $APP_DIR and workspace $WORKSPACE."
note "It does not create login autostart or connect your ChatGPT account."
printf 'Mac owner approves installing this Mac-only MCP and official tunnel binaries? [y/N]: '
read -r answer
[[ "$answer" == [yY] ]] || { note "Cancelled."; exit 2; }
for exe in curl shasum unzip install awk; do command -v "$exe" >/dev/null || fail "Missing macOS utility: $exe"; done
if ! command -v node >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    note "Installing official Node.js via Homebrew (owner approved Mac setup)."
    brew install node
  else
    fail "Node.js >=22.12 required. Install Node.js from https://nodejs.org/en/download (or Homebrew) and rerun."
  fi
fi
node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=12)?0:1)' \
  || fail "Node.js >=22.12 required. Update Node.js, then rerun."
mkdir -p "$APP_DIR" "$BIN_DIR" "$WORKSPACE"
chmod 700 "$APP_DIR" "$BIN_DIR"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-mac-bridge.XXXXXXXX")"
trap 'rm -rf "$tmp"' EXIT
download_checked() {
  local url="$1" expected="$2" output="$3" digest
  curl --fail --location --retry 2 --silent --show-error "$url" -o "$output" || fail "Download failed."
  digest="$(shasum -a 256 "$output" | awk '{print $1}')"
  [[ "$digest" == "$expected" ]] || fail "SHA-256 checksum mismatch; refusing installation."
}
download_checked \
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/86929a9a899550ac9f7e9a9b025ffe12bc5a1b79/macos/local-mac-mcp.cjs" \
  "e66adc3446b74fef77c4e37916d1653565bece60acf17db3d860aadb6c3386cb" \
  "$tmp/local-mac-mcp.cjs"
download_checked \
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/9e2baa53bc35859d1cef535a20ee83a31096d3bd/macos/CONNECT.sh" \
  "48d0b005d39df9c621af1acea7fc7251edd5f8a587fa844924a2005105c518e6" \
  "$tmp/CONNECT.sh"
download_checked \
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/94178fcf9331643bfcc20ae949070e840d1dccb1/macos/AUTOSTART.sh" \
  "ed296642d8c5b525faf26fc15565c535790035de38aba59298de1ccc6e77c38a" \
  "$tmp/AUTOSTART.sh"
node --check "$tmp/local-mac-mcp.cjs" || fail "MCP JS syntax check failed."
/bin/bash -n "$tmp/CONNECT.sh" "$tmp/AUTOSTART.sh" || fail "Shell script syntax check failed."
install -m 600 "$tmp/local-mac-mcp.cjs" "$APP_DIR/local-mac-mcp.cjs"
install -m 700 "$tmp/CONNECT.sh" "$APP_DIR/CONNECT.sh"
install -m 700 "$tmp/AUTOSTART.sh" "$APP_DIR/AUTOSTART.sh"
if [[ ! -x "$BIN_DIR/tunnel-client" || ! -x "$BIN_DIR/cloudflared" || ! -f "$BIN_DIR/cloudflared-manifest.json" ]]; then
  file="tunnel-client-$RELEASE-darwin-$ARCH.zip"
  note "Downloading official OpenAI macOS tunnel bundle: $RELEASE ($ARCH)."
  download_checked \
    "https://github.com/openai/tunnel-client/releases/download/$RELEASE/$file" \
    "$TUNNEL_SHA" "$tmp/$file"
  mkdir -p "$tmp/release"
  unzip -q "$tmp/$file" -d "$tmp/release" || fail "Official ZIP extraction failed."
  [[ -f "$tmp/release/tunnel-client" && -f "$tmp/release/cloudflared" &&
    -f "$tmp/release/cloudflared-manifest.json" ]] || fail "ZIP missing required tunnel runtime files."
  install -m 700 "$tmp/release/tunnel-client" "$BIN_DIR/tunnel-client"
  install -m 700 "$tmp/release/cloudflared" "$BIN_DIR/cloudflared"
  install -m 600 "$tmp/release/cloudflared-manifest.json" "$BIN_DIR/cloudflared-manifest.json"
else
  note "Existing complete Mac tunnel bundle found. Not overwriting a potentially running daemon."
fi
"$BIN_DIR/tunnel-client" --version || fail "Tunnel binary version check failed."
note "Mac-only MCP + official macOS tunnel + Keychain/LaunchAgent helper scripts installed."
note "No account connected; no login LaunchAgent enabled."
note "NEXT COMMAND: bash \"$APP_DIR/CONNECT.sh\""
