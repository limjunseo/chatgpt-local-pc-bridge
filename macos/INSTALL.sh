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
    CLIENT_SHA="4a82a4591933241850966ab3484cb39e65fad11b7e83b43891f6599f9638bd7f"
    CLOUD_SHA="5eba1c4bb3ab95b652d95c793d5f78f6747552ad2d1b2574b8e0ec33253b2df5"
    ;;
  x86_64)
    ARCH="amd64"
    TUNNEL_SHA="dff97674c77cac59e6ab3d901e6cff50fb17a5784c01d8959d1f4adb3afdf4bf"
    CLIENT_SHA="dfd9f50aa6846ba76223d4ceb86ab9408b794881b650b000ec0ef6fd2a8b775b"
    CLOUD_SHA="2f04e7bcd2d81bdeecd4a5ed24bc75302317189bd10478ba4127b3c41d6cbdba"
    ;;
  *) echo "[MAC INSTALL ERROR] Unsupported Mac architecture." >&2; exit 2 ;;
esac
fail() { printf '[MAC INSTALL ERROR] %s\n' "$1" >&2; exit 1; }
OS_VERSION="$(sw_vers -productVersion 2>/dev/null)" || fail "Cannot detect macOS version."
MAC_OS_MAJOR="${OS_VERSION%%.*}"
[[ "$MAC_OS_MAJOR" =~ ^[0-9]+$ && "$MAC_OS_MAJOR" -ge 13 ]] || fail "Requires macOS 13 Ventura or newer. Detected: $OS_VERSION"
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
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/0f7a9317da0176ec9d627574f154ae037906da41/macos/local-mac-mcp.cjs" \
  "bb2043f20d95a4ba2b35fa19c0fa26d45142a2cb6680830a94cfbe6ef7dd9c7f" \
  "$tmp/local-mac-mcp.cjs"
download_checked \
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/bad34386b6cd53f12f04fb4934c972578549db53/macos/CONNECT.sh" \
  "5947b65d4e18e0678b8a382cb1cc8d892eb00e163a9937f1caa6dea63f2cef9c" \
  "$tmp/CONNECT.sh"
download_checked \
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/9fd5ed7656be107b42517fd4a3af7b937785affd/macos/AUTOSTART.sh" \
  "14876944e741f1465abe72cb341fa851161f232ff8dc9991de4a0b4c62cd589c" \
  "$tmp/AUTOSTART.sh"
download_checked \
  "https://raw.githubusercontent.com/limjunseo/chatgpt-local-pc-bridge/aa0786a5bed1ec47b85455f32c6bd5723fbaa2a2/macos/CONFIG.sh" \
  "22b80fdbfa9b7545fd8d860d877fcbdc5c1f978db09b2a525f28d1ff2243d5bc" \
  "$tmp/CONFIG.sh"
node --check "$tmp/local-mac-mcp.cjs" || fail "MCP JS syntax check failed."
for script in CONNECT.sh AUTOSTART.sh CONFIG.sh; do
  /bin/bash -n "$tmp/$script" || fail "Syntax check failed: $script"
done
install -m 600 "$tmp/local-mac-mcp.cjs" "$APP_DIR/local-mac-mcp.cjs"
install -m 700 "$tmp/CONNECT.sh" "$APP_DIR/CONNECT.sh"
install -m 700 "$tmp/AUTOSTART.sh" "$APP_DIR/AUTOSTART.sh"
install -m 600 "$tmp/CONFIG.sh" "$APP_DIR/CONFIG.sh"
MANIFEST_SHA="04073cfbf4d2603f0054f80a4bef0aa5c07ca059fbe013ee4cbb35667a215164"
bundle_matches() {
  [[ -x "$BIN_DIR/tunnel-client" && -x "$BIN_DIR/cloudflared" && -f "$BIN_DIR/cloudflared-manifest.json" ]] || return 1
  [[ "$(shasum -a 256 "$BIN_DIR/tunnel-client" | awk '{print $1}')" == "$CLIENT_SHA" &&
     "$(shasum -a 256 "$BIN_DIR/cloudflared" | awk '{print $1}')" == "$CLOUD_SHA" &&
     "$(shasum -a 256 "$BIN_DIR/cloudflared-manifest.json" | awk '{print $1}')" == "$MANIFEST_SHA" ]]
}
if bundle_matches; then
  note "Existing Mac bundle has verified official file hashes. No running binaries overwritten."
elif [[ -e "$BIN_DIR/tunnel-client" || -e "$BIN_DIR/cloudflared" || -e "$BIN_DIR/cloudflared-manifest.json" ]]; then
  fail "Existing Mac bundle is incomplete or does not match official SHA-256. Stop the Mac tunnel, back up/remove only the three files under the Mac app bin folder, then rerun. Refusing unsafe overwrite."
else
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
fi
"$BIN_DIR/tunnel-client" --version || fail "Tunnel binary version check failed."
note "Mac-only MCP + official macOS tunnel + Keychain/LaunchAgent helper scripts installed."
note "No account connected; no login LaunchAgent enabled."
note "NEXT COMMAND: bash \"$APP_DIR/CONNECT.sh\""
