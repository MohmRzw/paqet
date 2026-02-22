#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_VERSION="1.1.0"
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
  install.sh [outside|iran|menu]
  install.sh --repo <github_user/repo> [outside|iran|menu]

Options:
  --repo <value>       Optional. Default: MohmRzw/paqet
  --branch <value>     Optional. Default: main
  --mode <value>       outside | iran | menu
  --install-path <p>   Optional install path. Default: /usr/local/bin/paqet-manager
  --no-run             Install only, do not run setup after install
  -h, --help           Show help

Examples:
  # Easiest (asks mode: outside / iran / menu)
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash

  # Direct mode (outside)
  curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside

  # Direct mode (iran)
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
1) outside
2) iran
3) menu
EOF

  if ans="$(read_prompt_line "Select [3]: ")"; then
    :
  else
    ans=""
  fi

  case "${ans:-3}" in
    1|outside) MODE="outside" ;;
    2|iran) MODE="iran" ;;
    3|menu|"") MODE="menu" ;;
    *) MODE="menu" ;;
  esac
}

run_installed_manager() {
  local mode="$1"
  if [[ -t 0 ]]; then
    "$INSTALL_PATH" "$mode"
    return
  fi
  if [[ -r /dev/tty ]]; then
    "$INSTALL_PATH" "$mode" < /dev/tty
    return
  fi
  die "No interactive TTY available for mode '${mode}'. Re-run with --no-run, then execute: $INSTALL_PATH $mode"
}

REPO="${GITHUB_REPO:-$DEFAULT_REPO}"
BRANCH="${GITHUB_BRANCH:-$DEFAULT_BRANCH}"
MODE="menu"
MODE_SET_BY_USER="no"
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
      MODE_SET_BY_USER="yes"
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
  outside|iran|menu) ;;
  *) die "Invalid mode: $MODE (use outside|iran|menu)" ;;
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
  log "Run manually: $INSTALL_PATH setup-outside | setup-iran | menu"
  exit 0
fi

case "$MODE" in
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
