#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_VERSION="1.2.0"
DEFAULT_REPO="MohmRzw/paqet"
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
  install.sh [outside-easy|iran-easy|outside|iran|menu]
  install.sh --repo <github_user/repo> [outside-easy|iran-easy|outside|iran|menu]

Options:
  --repo <value>       Optional. Default: MohmRzw/paqet
  --branch <value>     Optional. Default: main
  --mode <value>       outside-easy | iran-easy | outside | iran | menu
  --server <addr>      For iran-easy. Example: 203.0.113.10:9999
  --key <value>        For iran-easy. Shared Key from outside setup
  --target <host>      For iran-easy. Forward target host (default: host part of --server)
  --ports <csv>        For iran-easy. Default: 443,8443
  --install-path <p>   Optional install path. Default: /usr/local/bin/paqet-manager
  --no-run             Install only, do not run setup after install
  -h, --help           Show help

Examples:
  # Easiest (asks mode, defaults to outside-easy)
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash

  # One-line easy outside
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside-easy

  # One-line easy Iran
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- iran-easy --server 5.75.197.42:9999 --key YOUR_KEY

  # Full wizard mode (outside)
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside

  # Full wizard mode (iran)
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- iran
EOF
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run as root. Example: sudo bash <(curl ...)"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

read_prompt_line() {
  local prompt="$1"
  local value=""
  if [[ -t 0 ]]; then
    read -r -p "$prompt" value || return 1
    printf '%s' "$value"
    return 0
  fi
  if [[ -r /dev/tty ]]; then
    read -r -p "$prompt" value < /dev/tty || return 1
    printf '%s' "$value"
    return 0
  fi
  return 2
}

select_mode_if_needed() {
  local ans=""
  if [[ "$MODE_SET_BY_USER" == "yes" ]]; then
    return 0
  fi

  cat <<'EOF'

Choose install mode:
1) outside-easy (recommended)
2) iran-easy (recommended)
3) outside (full wizard)
4) iran (full wizard)
5) menu
EOF

  if ans="$(read_prompt_line "Select [1]: ")"; then
    :
  else
    ans=""
  fi

  case "${ans:-1}" in
    1|outside-easy) MODE="outside-easy" ;;
    2|iran-easy) MODE="iran-easy" ;;
    3|outside) MODE="outside" ;;
    4|iran) MODE="iran" ;;
    5|menu|"") MODE="menu" ;;
    *) MODE="outside-easy" ;;
  esac
}

run_installed_manager() {
  local mode="$1"
  shift
  if [[ -t 0 ]]; then
    "$INSTALL_PATH" "$mode" "$@"
    return
  fi
  if [[ -r /dev/tty ]]; then
    "$INSTALL_PATH" "$mode" "$@" < /dev/tty
    return
  fi
  "$INSTALL_PATH" "$mode" "$@"
}

REPO="${GITHUB_REPO:-$DEFAULT_REPO}"
BRANCH="${GITHUB_BRANCH:-$DEFAULT_BRANCH}"
MODE="outside-easy"
MODE_SET_BY_USER="no"
INSTALL_PATH="${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}"
AUTO_RUN="yes"
IRAN_SERVER_ADDR="${PAQET_OUTSIDE_ADDR:-}"
IRAN_SHARED_KEY="${PAQET_SHARED_KEY:-}"
IRAN_TARGET_HOST="${PAQET_EASY_FORWARD_TARGET:-}"
IRAN_PORTS="${PAQET_EASY_FORWARD_PORTS:-}"

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
      MODE_SET_BY_USER="yes"
      shift 2
      ;;
    --server)
      [[ $# -gt 1 ]] || die "--server requires a value"
      IRAN_SERVER_ADDR="$2"
      shift 2
      ;;
    --key)
      [[ $# -gt 1 ]] || die "--key requires a value"
      IRAN_SHARED_KEY="$2"
      shift 2
      ;;
    --target)
      [[ $# -gt 1 ]] || die "--target requires a value"
      IRAN_TARGET_HOST="$2"
      shift 2
      ;;
    --ports)
      [[ $# -gt 1 ]] || die "--ports requires a value"
      IRAN_PORTS="$2"
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
    outside-easy|setup-outside-easy)
      MODE="outside-easy"
      MODE_SET_BY_USER="yes"
      shift
      ;;
    iran-easy|setup-iran-easy)
      MODE="iran-easy"
      MODE_SET_BY_USER="yes"
      shift
      ;;
    outside|setup-outside)
      MODE="outside"
      MODE_SET_BY_USER="yes"
      shift
      ;;
    iran|setup-iran)
      MODE="iran"
      MODE_SET_BY_USER="yes"
      shift
      ;;
    menu)
      MODE="menu"
      MODE_SET_BY_USER="yes"
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

[[ "$REPO" != *"YOUR_"* ]] || die "Invalid repo value. Use real <user/repo>."
[[ "$REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || die "Invalid --repo format. Expected: <github_user/repo>"
[[ "$BRANCH" =~ ^[A-Za-z0-9._/-]+$ ]] || die "Invalid --branch format."

select_mode_if_needed

case "$MODE" in
  outside-easy|iran-easy|outside|iran|menu) ;;
  *) die "Invalid mode: $MODE (use outside-easy|iran-easy|outside|iran|menu)" ;;
esac

require_root
require_cmd curl
require_cmd install
require_cmd mktemp

if [[ "$REPO" == "$DEFAULT_REPO" ]]; then
  log "Using default repo: ${REPO}"
else
  log "Using custom repo: ${REPO}"
fi

SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/paqet.sh"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

log "Downloading manager script from: ${SCRIPT_URL}"
curl -fsSL "$SCRIPT_URL" -o "$TMP_FILE" || die "Failed to download paqet.sh from ${SCRIPT_URL}"

mkdir -p "$(dirname "$INSTALL_PATH")"
install -m 0755 "$TMP_FILE" "$INSTALL_PATH"
ok "Installed: $INSTALL_PATH"

mkdir -p /etc/paqet
cat > /etc/paqet/source.env <<EOF
PAQET_BOOTSTRAP_REPO='${REPO}'
PAQET_BOOTSTRAP_BRANCH='${BRANCH}'
PAQET_BINARY_BASE_URL='https://raw.githubusercontent.com/${REPO}/${BRANCH}'
EOF
ok "Saved binary source: /etc/paqet/source.env"

if [[ "$AUTO_RUN" == "no" ]]; then
  log "Install only mode completed."
  log "Run manually: $INSTALL_PATH setup-outside-easy | setup-iran-easy | setup-outside | setup-iran | menu"
  exit 0
fi

case "$MODE" in
  outside-easy)
    log "Running easy setup for outside server..."
    run_installed_manager setup-outside-easy
    ;;
  iran-easy)
    log "Running easy setup for Iran server..."
    if [[ -n "$IRAN_PORTS" ]]; then
      run_installed_manager setup-iran-easy "$IRAN_SERVER_ADDR" "$IRAN_SHARED_KEY" "$IRAN_TARGET_HOST" "$IRAN_PORTS"
    elif [[ -n "$IRAN_TARGET_HOST" ]]; then
      run_installed_manager setup-iran-easy "$IRAN_SERVER_ADDR" "$IRAN_SHARED_KEY" "$IRAN_TARGET_HOST"
    elif [[ -n "$IRAN_SHARED_KEY" || -n "$IRAN_SERVER_ADDR" ]]; then
      run_installed_manager setup-iran-easy "$IRAN_SERVER_ADDR" "$IRAN_SHARED_KEY"
    else
      run_installed_manager setup-iran-easy
    fi
    ;;
  outside)
    log "Running full setup for outside server..."
    run_installed_manager setup-outside
    ;;
  iran)
    log "Running full setup for Iran server..."
    run_installed_manager setup-iran
    ;;
  menu)
    log "Opening interactive menu..."
    run_installed_manager menu
    ;;
esac
