#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_VERSION="1.0.0"
DEFAULT_BRANCH="main"
DEFAULT_INSTALL_PATH="/usr/local/bin/paqet-manager"

log() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
err() { printf '[ERROR] %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

usage() {
  cat <<'EOF'
PAQET bootstrap installer

Usage:
  install.sh --repo <github_user/repo> [outside|iran|menu]
  install.sh --repo <github_user/repo> --mode outside

Options:
  --repo <value>       Required. Example: myuser/paqet
  --branch <value>     Optional. Default: main
  --mode <value>       outside | iran | menu (default: menu)
  --install-path <p>   Optional install path. Default: /usr/local/bin/paqet-manager
  --no-run             Install only, do not run setup after install
  -h, --help           Show help

Examples:
  REPO="myuser/paqet"; sudo bash <(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install.sh") --repo "$REPO" outside
  REPO="myuser/paqet"; sudo bash <(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install.sh") --repo "$REPO" iran
EOF
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run as root. Example: sudo bash <(curl ...)"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

REPO="${GITHUB_REPO:-}"
BRANCH="${GITHUB_BRANCH:-$DEFAULT_BRANCH}"
MODE="menu"
INSTALL_PATH="${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}"
AUTO_RUN="yes"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -gt 1 ]] || die "--repo requires a value"
      REPO="$2"
      shift 2
      ;;
    --branch)
      [[ $# -gt 1 ]] || die "--branch requires a value"
      BRANCH="$2"
      shift 2
      ;;
    --mode)
      [[ $# -gt 1 ]] || die "--mode requires a value"
      MODE="$2"
      shift 2
      ;;
    --install-path)
      [[ $# -gt 1 ]] || die "--install-path requires a value"
      INSTALL_PATH="$2"
      shift 2
      ;;
    --no-run)
      AUTO_RUN="no"
      shift
      ;;
    outside|setup-outside)
      MODE="outside"
      shift
      ;;
    iran|setup-iran)
      MODE="iran"
      shift
      ;;
    menu)
      MODE="menu"
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (use --help)"
      ;;
  esac
done

[[ -n "$REPO" ]] || die "Missing --repo <github_user/repo>"
[[ "$REPO" != *"YOUR_"* ]] || die "Invalid repo value. Use real <user/repo>."

case "$MODE" in
  outside|iran|menu) ;;
  *) die "Invalid mode: $MODE (use outside|iran|menu)" ;;
esac

require_root
require_cmd curl

SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/paqet.sh"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

log "Downloading manager script from: ${SCRIPT_URL}"
curl -fsSL "$SCRIPT_URL" -o "$TMP_FILE" || die "Failed to download paqet.sh from ${SCRIPT_URL}"

mkdir -p "$(dirname "$INSTALL_PATH")"
install -m 0755 "$TMP_FILE" "$INSTALL_PATH"
ok "Installed: $INSTALL_PATH"

if [[ "$AUTO_RUN" == "no" ]]; then
  log "Install only mode completed."
  log "Run manually: $INSTALL_PATH setup-outside | setup-iran | menu"
  exit 0
fi

case "$MODE" in
  outside)
    log "Running full setup for outside server..."
    "$INSTALL_PATH" setup-outside
    ;;
  iran)
    log "Running full setup for Iran server..."
    "$INSTALL_PATH" setup-iran
    ;;
  menu)
    log "Opening interactive menu..."
    "$INSTALL_PATH" menu
    ;;
esac
