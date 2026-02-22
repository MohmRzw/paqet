#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.3.0"
APP_NAME="paqet"
SERVICE_NAME="paqet"
REPO="hanselime/paqet"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

BIN_PATH="/usr/local/bin/paqet"
ETC_DIR="/etc/paqet"
CONFIG_PATH="${ETC_DIR}/config.yaml"
ROLE_PATH="${ETC_DIR}/role"
STATE_PATH="${ETC_DIR}/state.env"
BACKUP_DIR="${ETC_DIR}/backup"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

ARCH=""

on_error() {
  local line="$1"
  local cmd="$2"
  printf '[ERROR] line %s: %s\n' "$line" "$cmd" >&2
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
${APP_NAME} manager script v${SCRIPT_VERSION}

Usage:
  # Setup (simple and recommended)
  ${0##*/} setup-outside   # full setup for outside server
  ${0##*/} setup-iran      # full setup for Iran client

  # Install
  ${0##*/} install
  ${0##*/} update

  # Configure only
  ${0##*/} config-outside
  ${0##*/} config-iran

  # Manage
  ${0##*/} service-create
  ${0##*/} start|stop|restart|status|logs|logs-follow
  ${0##*/} ping
  ${0##*/} iface
  ${0##*/} show

  # Edit / Remove
  ${0##*/} edit-config
  ${0##*/} backup-config
  ${0##*/} uninstall

  # Advanced network rule commands (outside server only)
  ${0##*/} net-prepare [PORT]
  ${0##*/} net-clean [PORT]
  ${0##*/} net-save

  # Utilities
  ${0##*/} secret
  ${0##*/} quick-guide
  ${0##*/} menu

Notes:
  - Linux only
  - Must run as root
  - setup-outside + setup-iran are one-shot full setup commands
  - setup-iran can ask and save your forward ports directly
EOF
}

exists() { command -v "$1" >/dev/null 2>&1; }

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Please run as root."
}

ensure_dirs() {
  mkdir -p "${ETC_DIR}" "${BACKUP_DIR}"
}

prompt_default() {
  local msg="$1"
  local default="${2-}"
  local value=""
  if [[ -n "$default" ]]; then
    read -r -p "${msg} [${default}]: " value || true
    printf '%s' "${value:-$default}"
  else
    read -r -p "${msg}: " value || true
    printf '%s' "$value"
  fi
}

confirm() {
  local msg="$1"
  local ans=""
  read -r -p "${msg} [y/N]: " ans || true
  ans="${ans,,}"
  [[ "$ans" == "y" || "$ans" == "yes" ]]
}

confirm_yes_default() {
  local msg="$1"
  local ans=""
  read -r -p "${msg} [Y/n]: " ans || true
  ans="${ans,,}"
  [[ -z "$ans" || "$ans" == "y" || "$ans" == "yes" ]]
}

show_sample_notice() {
  cat <<'EOF'
IMPORTANT:
- Examples are placeholders.
- Do NOT enter these literals: x.x.x.x, aa:bb:cc:dd:ee:ff, example.com, your-domain.com
- Replace examples with your real values.
EOF
}

is_placeholder_value() {
  local v="${1,,}"
  [[ "$v" == *"x.x.x.x"* ]] && return 0
  [[ "$v" == *"aa:bb:cc:dd:ee:ff"* ]] && return 0
  [[ "$v" == *"example.com"* ]] && return 0
  [[ "$v" == *"your-domain.com"* ]] && return 0
  [[ "$v" == *"ip_or_domain"* ]] && return 0
  [[ "$v" == *"your_ip"* ]] && return 0
  [[ "$v" == *"your-server"* ]] && return 0
  [[ "$v" == *"shared-key"* ]] && return 0
  [[ "$v" == *"your-key"* ]] && return 0
  return 1
}

yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

is_valid_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 ))
}

is_valid_mac() {
  local mac="$1"
  [[ "$mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
}

extract_port() {
  local addr="$1"
  printf '%s' "${addr##*:}"
}

detect_arch() {
  local os
  local raw_arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  [[ "$os" == "linux" ]] || die "This script supports Linux only."
  raw_arch="$(uname -m)"
  case "$raw_arch" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armv6l|armhf|arm) ARCH="arm32" ;;
    mips) ARCH="mips" ;;
    mips64) ARCH="mips64" ;;
    mips64el|mips64le) ARCH="mips64le" ;;
    mipsel|mipsle) ARCH="mipsle" ;;
    *) die "Unsupported arch: ${raw_arch}" ;;
  esac
}

detect_pkg_manager() {
  if exists apt-get; then echo "apt-get"; return; fi
  if exists dnf; then echo "dnf"; return; fi
  if exists yum; then echo "yum"; return; fi
  if exists pacman; then echo "pacman"; return; fi
  if exists zypper; then echo "zypper"; return; fi
  if exists apk; then echo "apk"; return; fi
  echo ""
}

install_dependencies() {
  local missing=()
  local pm
  local c
  for c in curl tar ip iptables awk sed grep; do
    exists "$c" || missing+=("$c")
  done
  [[ "${#missing[@]}" -eq 0 ]] && return 0

  pm="$(detect_pkg_manager)"
  [[ -n "$pm" ]] || die "Missing dependencies: ${missing[*]} and no supported package manager found."

  info "Installing dependencies with ${pm}: ${missing[*]}"
  case "$pm" in
    apt-get)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y curl tar iproute2 iptables ca-certificates
      ;;
    dnf) dnf install -y curl tar iproute iptables ca-certificates ;;
    yum) yum install -y curl tar iproute iptables ca-certificates ;;
    pacman) pacman -Sy --noconfirm curl tar iproute2 iptables ca-certificates ;;
    zypper) zypper --non-interactive in curl tar iproute2 iptables ca-certificates ;;
    apk) apk add --no-cache curl tar iproute2 iptables ca-certificates ;;
  esac
}

fetch_latest_json() {
  curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: paqet-manager" "${API_URL}"
}

latest_tag() {
  local tag
  tag="$(fetch_latest_json | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
  [[ -n "$tag" ]] || die "Could not read latest release tag."
  printf '%s' "$tag"
}

download_url_for_arch() {
  local json url
  json="$(fetch_latest_json)"
  url="$(printf '%s\n' "$json" \
    | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' \
    | grep -E "/paqet-linux-${ARCH}-.*\\.tar\\.gz$" \
    | head -n1 || true)"
  [[ -n "$url" ]] || die "No Linux asset found for arch ${ARCH}"
  printf '%s' "$url"
}

installed_version() {
  [[ -x "${BIN_PATH}" ]] || return 1
  "${BIN_PATH}" version 2>/dev/null | awk -F':[[:space:]]*' '/^Version:/ {print $2; exit}'
}

install_binary() {
  detect_arch
  install_dependencies
  ensure_dirs

  local tag url current tmp archive exe
  tag="$(latest_tag)"
  url="$(download_url_for_arch)"
  current="$(installed_version || true)"

  if [[ -n "$current" && "$current" == "$tag" ]]; then
    ok "paqet ${current} is already installed."
    return 0
  fi

  info "Downloading ${tag} for linux/${ARCH}"
  tmp="$(mktemp -d)"
  archive="${tmp}/paqet.tar.gz"
  curl -fL "$url" -o "$archive"
  tar -xzf "$archive" -C "$tmp"

  exe="$(find "$tmp" -maxdepth 2 -type f -name 'paqet_linux_*' | head -n1 || true)"
  [[ -n "$exe" ]] || exe="$(find "$tmp" -maxdepth 2 -type f -name 'paqet' | head -n1 || true)"
  [[ -n "$exe" ]] || die "Could not find extracted paqet binary."

  install -m 0755 "$exe" "$BIN_PATH"
  cat > "$STATE_PATH" <<EOF
TAG=${tag}
ARCH=${ARCH}
INSTALLED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
URL=${url}
EOF
  rm -rf "$tmp"

  ok "Installed: ${BIN_PATH}"
  "${BIN_PATH}" version || true
}

auto_iface() {
  ip -o -4 route show to default | awk '{print $5; exit}'
}

auto_gateway() {
  ip route | awk '/^default/ {print $3; exit}'
}

auto_ipv4() {
  local iface="$1"
  ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1
}

auto_router_mac() {
  local iface="$1"
  local gw="$2"
  local mac
  if exists ping; then ping -c 1 -W 1 "$gw" >/dev/null 2>&1 || true; fi
  mac="$(ip neigh show "$gw" dev "$iface" 2>/dev/null | awk '{print $5; exit}' || true)"
  printf '%s' "$mac"
}

generate_secret() {
  if [[ -x "$BIN_PATH" ]]; then
    "$BIN_PATH" secret 2>/dev/null | tr -d '\r\n'
    return
  fi
  if exists openssl; then
    openssl rand -hex 32 | tr -d '\r\n'
    return
  fi
  head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

write_server_config() {
  local iface="$1"
  local ip="$2"
  local router_mac="$3"
  local port="$4"
  local key="$5"
  local level="$6"
  ensure_dirs
  cat > "$CONFIG_PATH" <<EOF
role: "server"

log:
  level: "$(yaml_escape "$level")"

listen:
  addr: ":${port}"

network:
  interface: "$(yaml_escape "$iface")"
  ipv4:
    addr: "$(yaml_escape "${ip}:${port}")"
    router_mac: "$(yaml_escape "$router_mac")"

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    block: "aes"
    key: "$(yaml_escape "$key")"
EOF
  printf 'server\n' > "$ROLE_PATH"
  ok "Server config written: ${CONFIG_PATH}"
}

write_client_config() {
  local iface="$1"
  local ip="$2"
  local router_mac="$3"
  local server_addr="$4"
  local socks_addr="$5"
  local key="$6"
  local level="$7"
  local user="$8"
  local pass="$9"
  local use_socks="${10:-yes}"
  local forward_block="${11:-}"
  ensure_dirs
  {
    echo 'role: "client"'
    echo
    echo "log:"
    echo "  level: \"$(yaml_escape "$level")\""
    echo
    if [[ "$use_socks" == "yes" ]]; then
      echo "socks5:"
      echo "  - listen: \"$(yaml_escape "$socks_addr")\""
      echo "    username: \"$(yaml_escape "$user")\""
      echo "    password: \"$(yaml_escape "$pass")\""
      echo
    fi
    if [[ -n "$forward_block" ]]; then
      printf '%s\n' "$forward_block"
      echo
    fi
    echo "network:"
    echo "  interface: \"$(yaml_escape "$iface")\""
    echo "  ipv4:"
    echo "    addr: \"$(yaml_escape "${ip}:0")\""
    echo "    router_mac: \"$(yaml_escape "$router_mac")\""
    echo
    echo "server:"
    echo "  addr: \"$(yaml_escape "$server_addr")\""
    echo
    echo "transport:"
    echo "  protocol: \"kcp\""
    echo "  conn: 1"
    echo "  kcp:"
    echo "    mode: \"fast\""
    echo "    block: \"aes\""
    echo "    key: \"$(yaml_escape "$key")\""
  } > "$CONFIG_PATH"
  printf 'client\n' > "$ROLE_PATH"
  ok "Client config written: ${CONFIG_PATH}"
}

public_ipv4() {
  curl -4fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true
}

show_outside_next_info() {
  local server_ip="$1"
  local port="$2"
  local key="$3"
  local public_ip
  public_ip="$(public_ipv4)"
  if [[ -n "$public_ip" ]]; then
    server_ip="$public_ip"
  fi
  echo
  echo "===== Values you need on Iran server ====="
  echo "Server Address: ${server_ip}:${port}"
  echo "Shared Key: ${key}"
  echo "Next step on Iran server (no manual file editing needed):"
  echo "sudo ./paqet.sh setup-iran"
  echo
}

show_iran_test_info() {
  local use_socks="${1:-yes}"
  local socks_addr="${2:-127.0.0.1:1080}"
  local first_listen="${3:-}"
  local first_target="${4:-}"
  local first_proto="${5:-}"
  echo
  echo "===== Test on Iran server ====="
  if [[ "$use_socks" == "yes" ]]; then
    echo "SOCKS5 test:"
    echo "curl -v https://httpbin.org/ip --proxy socks5h://${socks_addr}"
  fi
  if [[ -n "$first_listen" ]]; then
    echo "Forward test:"
    echo "Connect your app to ${first_listen}"
    echo "Forward target is ${first_target} (${first_proto})"
  fi
  echo
}

wizard_server() {
  local iface gw ip mac port key level
  local iface_d gw_d ip_d mac_d

  iface_d="$(auto_iface || true)"
  gw_d="$(auto_gateway || true)"
  ip_d=""
  mac_d=""
  [[ -n "$iface_d" ]] && ip_d="$(auto_ipv4 "$iface_d" || true)"
  [[ -n "$iface_d" && -n "$gw_d" ]] && mac_d="$(auto_router_mac "$iface_d" "$gw_d" || true)"

  info "Configure outside server"
  show_sample_notice
  echo "Press Enter to accept suggested values."
  echo "Detected values:"
  echo "  interface: ${iface_d:-not found}"
  echo "  local ip:  ${ip_d:-not found}"
  echo "  gateway:   ${gw_d:-not found}"
  echo "  gw mac:    ${mac_d:-not found}"

  if confirm_yes_default "Use detected values?"; then
    iface="${iface_d:-eth0}"
    ip="${ip_d:-}"
    mac="${mac_d:-}"
  else
    iface="$(prompt_default "Network interface name (example: eth0 or ens3)" "${iface_d:-eth0}")"
    while [[ -z "$iface" ]]; do iface="$(prompt_default "Network interface name (example: eth0 or ens3)" "${iface_d:-eth0}")"; done

    gw="$(prompt_default "Gateway IPv4 (optional, example: 192.168.1.1)" "${gw_d:-}")"
    ip="$(prompt_default "Local IPv4 of this outside server (example: 10.0.0.10)" "${ip_d:-}")"
    while [[ -z "$ip" ]] || is_placeholder_value "$ip"; do
      warn "Enter a real IPv4. Do not use placeholder values."
      ip="$(prompt_default "Local IPv4 of this outside server (example: 10.0.0.10)" "${ip_d:-}")"
    done
    if [[ -n "$gw" ]]; then
      mac_d="$(auto_router_mac "$iface" "$gw" || true)"
    fi
    mac="$(prompt_default "Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)" "${mac_d:-}")"
  fi

  if [[ -z "$ip" ]] || is_placeholder_value "$ip"; then
    ip="$(prompt_default "Local IPv4 of this outside server (example: 10.0.0.10)" "${ip_d:-}")"
  fi
  while [[ -z "$ip" ]] || is_placeholder_value "$ip"; do
    warn "Enter a real IPv4. Do not use placeholder values."
    ip="$(prompt_default "Local IPv4 of this outside server (example: 10.0.0.10)" "${ip_d:-}")"
  done

  if [[ -z "$mac" ]]; then
    mac="$(prompt_default "Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)" "${mac_d:-}")"
  fi
  while ! is_valid_mac "$mac" || is_placeholder_value "$mac"; do
    warn "Invalid/placeholder MAC. Enter a real MAC like 12:34:56:78:9a:bc."
    mac="$(prompt_default "Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)" "${mac_d:-}")"
  done

  port="$(prompt_default "Tunnel port on outside server (example: 9999)" "9999")"
  while ! is_valid_port "$port"; do
    warn "Invalid port."
    port="$(prompt_default "Tunnel port on outside server (example: 9999)" "9999")"
  done

  key="$(prompt_default "Shared Key (example format: 64 hex chars, do not type shared-key)" "$(generate_secret)")"
  while [[ -z "$key" ]] || is_placeholder_value "$key"; do
    warn "Enter a real Shared Key. Do not use placeholder values."
    key="$(prompt_default "Shared Key (example format: 64 hex chars, do not type shared-key)" "$(generate_secret)")"
  done

  level="$(prompt_default "Log level (example: info)" "info")"

  if [[ -f "$CONFIG_PATH" ]] && ! confirm "Overwrite ${CONFIG_PATH}?"; then
    warn "Cancelled."
    return 1
  fi
  write_server_config "$iface" "$ip" "$mac" "$port" "$key" "$level"
  show_outside_next_info "$ip" "$port" "$key"
}

wizard_client() {
  local iface gw ip mac server socks key level user pass
  local use_socks forward_block
  local forward_count first_forward_listen first_forward_target first_forward_proto
  local listen target proto idx
  local bulk_target_host bulk_listen_ip bulk_proto bulk_ports
  local entry local_port remote_port listen_addr target_addr added_count
  local -a bulk_entries=()
  local iface_d gw_d ip_d mac_d

  iface_d="$(auto_iface || true)"
  gw_d="$(auto_gateway || true)"
  ip_d=""
  mac_d=""
  [[ -n "$iface_d" ]] && ip_d="$(auto_ipv4 "$iface_d" || true)"
  [[ -n "$iface_d" && -n "$gw_d" ]] && mac_d="$(auto_router_mac "$iface_d" "$gw_d" || true)"

  info "Configure Iran server (client side)"
  show_sample_notice
  echo "Press Enter to accept suggested values."
  echo "Detected values:"
  echo "  interface: ${iface_d:-not found}"
  echo "  local ip:  ${ip_d:-not found}"
  echo "  gateway:   ${gw_d:-not found}"
  echo "  gw mac:    ${mac_d:-not found}"

  if confirm_yes_default "Use detected values?"; then
    iface="${iface_d:-eth0}"
    ip="${ip_d:-}"
    mac="${mac_d:-}"
  else
    iface="$(prompt_default "Network interface name (example: eth0 or ens3)" "${iface_d:-eth0}")"
    while [[ -z "$iface" ]]; do iface="$(prompt_default "Network interface name (example: eth0 or ens3)" "${iface_d:-eth0}")"; done

    gw="$(prompt_default "Gateway IPv4 (optional, example: 192.168.1.1)" "${gw_d:-}")"
    ip="$(prompt_default "Local IPv4 of this Iran server (example: 10.10.10.20)" "${ip_d:-}")"
    while [[ -z "$ip" ]] || is_placeholder_value "$ip"; do
      warn "Enter a real IPv4. Do not use placeholder values."
      ip="$(prompt_default "Local IPv4 of this Iran server (example: 10.10.10.20)" "${ip_d:-}")"
    done
    if [[ -n "$gw" ]]; then
      mac_d="$(auto_router_mac "$iface" "$gw" || true)"
    fi
    mac="$(prompt_default "Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)" "${mac_d:-}")"
  fi

  if [[ -z "$ip" ]] || is_placeholder_value "$ip"; then
    ip="$(prompt_default "Local IPv4 of this Iran server (example: 10.10.10.20)" "${ip_d:-}")"
  fi
  while [[ -z "$ip" ]] || is_placeholder_value "$ip"; do
    warn "Enter a real IPv4. Do not use placeholder values."
    ip="$(prompt_default "Local IPv4 of this Iran server (example: 10.10.10.20)" "${ip_d:-}")"
  done

  if [[ -z "$mac" ]]; then
    mac="$(prompt_default "Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)" "${mac_d:-}")"
  fi
  while ! is_valid_mac "$mac" || is_placeholder_value "$mac"; do
    warn "Invalid/placeholder MAC. Enter a real MAC like 12:34:56:78:9a:bc."
    mac="$(prompt_default "Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)" "${mac_d:-}")"
  done

  server="$(prompt_default "Outside server address (example: 203.0.113.10:9999, do not type x.x.x.x)" "")"
  while [[ -z "$server" ]] || ! is_valid_port "$(extract_port "$server")" || is_placeholder_value "$server"; do
    warn "Invalid/placeholder outside server address. Example format: 203.0.113.10:9999"
    server="$(prompt_default "Outside server address (example: 203.0.113.10:9999, do not type x.x.x.x)" "$server")"
  done

  use_socks="yes"
  if confirm_yes_default "Enable local SOCKS5 for apps?"; then
    socks="$(prompt_default "Local SOCKS5 address (example: 127.0.0.1:1080)" "127.0.0.1:1080")"
    while ! is_valid_port "$(extract_port "$socks")"; do
      warn "Invalid local SOCKS5 port."
      socks="$(prompt_default "Local SOCKS5 address (example: 127.0.0.1:1080)" "$socks")"
    done
    if confirm "Enable username/password for local SOCKS5?"; then
      user="$(prompt_default "Username (example: myuser)" "")"
      pass="$(prompt_default "Password (example: mypass123)" "")"
    else
      user=""
      pass=""
    fi
  else
    use_socks="no"
    socks="127.0.0.1:1080"
    user=""
    pass=""
  fi

  forward_block=""
  forward_count=0
  first_forward_listen=""
  first_forward_target=""
  first_forward_proto=""
  if confirm_yes_default "Add direct app ports now (forward rules)?"; then
    if confirm_yes_default "Use BULK input (comma-separated ports)?"; then
      echo
      echo "Bulk format options:"
      echo "- Same local/target port list: 7001,7002,7003"
      echo "- Local:Target mapping list:   7001:443,7002:8443"
      echo "Do NOT type placeholders like example.com literally."

      bulk_target_host="$(prompt_default "Bulk target host/domain (example: 93.184.216.34 or your-real-domain.com)" "")"
      while [[ -z "$bulk_target_host" ]] || is_placeholder_value "$bulk_target_host"; do
        warn "Enter a real host/domain for bulk target."
        bulk_target_host="$(prompt_default "Bulk target host/domain (example: 93.184.216.34 or your-real-domain.com)" "$bulk_target_host")"
      done

      bulk_listen_ip="$(prompt_default "Bulk local listen IP (example: 127.0.0.1)" "127.0.0.1")"
      while [[ -z "$bulk_listen_ip" ]] || is_placeholder_value "$bulk_listen_ip"; do
        warn "Enter a real local listen IP."
        bulk_listen_ip="$(prompt_default "Bulk local listen IP (example: 127.0.0.1)" "$bulk_listen_ip")"
      done

      bulk_proto="$(prompt_default "Bulk protocol for all rules (tcp/udp)" "tcp")"
      bulk_proto="${bulk_proto,,}"
      while [[ "$bulk_proto" != "tcp" && "$bulk_proto" != "udp" ]]; do
        warn "Protocol must be tcp or udp."
        bulk_proto="$(prompt_default "Bulk protocol for all rules (tcp/udp)" "tcp")"
        bulk_proto="${bulk_proto,,}"
      done

      while true; do
        bulk_ports="$(prompt_default "Bulk ports list (example: 7001,7002 or 7001:443,7002:8443)" "")"
        bulk_ports="${bulk_ports//[[:space:]]/}"
        if [[ -z "$bulk_ports" ]]; then
          warn "Port list is empty."
          continue
        fi

        IFS=',' read -r -a bulk_entries <<< "$bulk_ports"
        added_count=0

        for entry in "${bulk_entries[@]}"; do
          [[ -z "$entry" ]] && continue
          if [[ "$entry" == *:* ]]; then
            local_port="${entry%%:*}"
            remote_port="${entry##*:}"
          else
            local_port="$entry"
            remote_port="$entry"
          fi

          if ! is_valid_port "$local_port"; then
            warn "Skip invalid local port token: $entry"
            continue
          fi
          if ! is_valid_port "$remote_port"; then
            warn "Skip invalid target port token: $entry"
            continue
          fi

          listen_addr="${bulk_listen_ip}:${local_port}"
          target_addr="${bulk_target_host}:${remote_port}"

          if (( forward_count == 0 )); then
            forward_block+="forward:"$'\n'
            first_forward_listen="$listen_addr"
            first_forward_target="$target_addr"
            first_forward_proto="$bulk_proto"
          fi

          forward_block+="  - listen: \"$(yaml_escape "$listen_addr")\""$'\n'
          forward_block+="    target: \"$(yaml_escape "$target_addr")\""$'\n'
          forward_block+="    protocol: \"$(yaml_escape "$bulk_proto")\""$'\n'
          forward_count=$((forward_count + 1))
          added_count=$((added_count + 1))
        done

        if (( added_count == 0 )); then
          warn "No valid ports parsed from list. Try again."
          continue
        fi

        ok "Added ${added_count} forward rule(s) from bulk list."
        if ! confirm_yes_default "Add another bulk list?"; then
          break
        fi
      done
    else
      idx=1
      while true; do
        echo
        echo "Forward rule #${idx}"
        echo "App -> local port on Iran server -> tunnel -> target"
        listen="$(prompt_default "Local listen address (example: 127.0.0.1:$((7000 + idx)))" "127.0.0.1:$((7000 + idx))")"
        while ! is_valid_port "$(extract_port "$listen")"; do
          warn "Invalid local listen port."
          listen="$(prompt_default "Local listen address (example: 127.0.0.1:$((7000 + idx)))" "$listen")"
        done

        target="$(prompt_default "Target via tunnel (example: 93.184.216.34:443 or your-domain.com:443, do not type example literally)" "")"
        while [[ -z "$target" ]] || ! is_valid_port "$(extract_port "$target")" || is_placeholder_value "$target"; do
          warn "Invalid/placeholder target. Use a real IP/domain:port."
          target="$(prompt_default "Target via tunnel (example: 93.184.216.34:443 or your-domain.com:443, do not type example literally)" "$target")"
        done

        proto="$(prompt_default "Protocol (example: tcp)" "tcp")"
        proto="${proto,,}"
        while [[ "$proto" != "tcp" && "$proto" != "udp" ]]; do
          warn "Protocol must be tcp or udp."
          proto="$(prompt_default "Protocol (example: tcp)" "tcp")"
          proto="${proto,,}"
        done

        if (( forward_count == 0 )); then
          forward_block+="forward:"$'\n'
          first_forward_listen="$listen"
          first_forward_target="$target"
          first_forward_proto="$proto"
        fi
        forward_block+="  - listen: \"$(yaml_escape "$listen")\""$'\n'
        forward_block+="    target: \"$(yaml_escape "$target")\""$'\n'
        forward_block+="    protocol: \"$(yaml_escape "$proto")\""$'\n'
        forward_count=$((forward_count + 1))
        idx=$((idx + 1))

        if ! confirm_yes_default "Add another forward rule?"; then
          break
        fi
      done
    fi
  fi

  if [[ "$use_socks" == "no" && "$forward_count" -eq 0 ]]; then
    warn "No SOCKS5 and no forward rule selected. Enabling SOCKS5 with default 127.0.0.1:1080."
    use_socks="yes"
    socks="127.0.0.1:1080"
    user=""
    pass=""
  fi

  key="$(prompt_default "Shared Key (same as outside server, do not type shared-key)" "")"
  while [[ -z "$key" ]] || is_placeholder_value "$key"; do
    warn "Enter the real Shared Key from outside server."
    key="$(prompt_default "Shared Key (required, do not type shared-key)" "")"
  done
  level="$(prompt_default "Log level (example: info)" "info")"

  if [[ -f "$CONFIG_PATH" ]] && ! confirm "Overwrite ${CONFIG_PATH}?"; then
    warn "Cancelled."
    return 1
  fi
  write_client_config "$iface" "$ip" "$mac" "$server" "$socks" "$key" "$level" "$user" "$pass" "$use_socks" "$forward_block"
  show_iran_test_info "$use_socks" "$socks" "$first_forward_listen" "$first_forward_target" "$first_forward_proto"
}

ensure_systemd() {
  exists systemctl || die "systemctl not found."
  [[ -d /run/systemd/system ]] || die "systemd is not active."
}

ensure_binary() {
  [[ -x "$BIN_PATH" ]] || die "Binary not found: ${BIN_PATH}. Run install first."
}

create_service() {
  ensure_systemd
  ensure_binary
  [[ -f "$CONFIG_PATH" ]] || die "Config missing: ${CONFIG_PATH}"
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=paqet raw packet tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_PATH} run -c ${CONFIG_PATH}
Restart=on-failure
RestartSec=2
User=root
Group=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
  ok "Service created: ${SERVICE_PATH}"
}

service_ctl() {
  local action="$1"
  ensure_systemd
  [[ -f "$SERVICE_PATH" ]] || die "Service file missing. Run service-create first."
  systemctl "$action" "$SERVICE_NAME"
}

service_status() {
  ensure_systemd
  systemctl --no-pager --full status "$SERVICE_NAME" || true
}

service_logs() {
  ensure_systemd
  journalctl -u "$SERVICE_NAME" -n "${1:-120}" --no-pager
}

service_logs_follow() {
  ensure_systemd
  journalctl -u "$SERVICE_NAME" -f
}

service_restart_or_start() {
  ensure_systemd
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl restart "$SERVICE_NAME"
  else
    systemctl start "$SERVICE_NAME"
  fi
}

server_port_from_config() {
  [[ -f "$CONFIG_PATH" ]] || return 1
  local addr
  addr="$(awk '
    /^[[:space:]]*listen:[[:space:]]*$/ {in_listen=1; next}
    in_listen && /^[[:space:]]*addr:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*addr:[[:space:]]*/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      gsub(/"/, "", line)
      print line
      exit
    }
    in_listen && /^[^[:space:]]/ {in_listen=0}
  ' "$CONFIG_PATH" || true)"
  [[ -n "$addr" ]] || return 1
  extract_port "$addr"
}

resolve_server_port() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    p="$(server_port_from_config || true)"
  fi
  is_valid_port "$p" || die "Invalid or missing server port."
  printf '%s' "$p"
}

iptables_has() {
  local table="$1"
  shift
  iptables -t "$table" -C "$@" >/dev/null 2>&1
}

iptables_add() {
  local table="$1"
  shift
  iptables_has "$table" "$@" || iptables -t "$table" -A "$@"
}

iptables_del() {
  local table="$1"
  shift
  iptables_has "$table" "$@" && iptables -t "$table" -D "$@"
}

firewall_apply() {
  local port
  port="$(resolve_server_port "${1:-}")"
  info "Applying required outside-server network rules for TCP/${port}"
  iptables_add raw PREROUTING -p tcp --dport "$port" -j NOTRACK
  iptables_add raw OUTPUT -p tcp --sport "$port" -j NOTRACK
  iptables_add mangle OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP
  ok "Firewall rules applied for TCP/${port}"
}

firewall_remove() {
  local port
  port="$(resolve_server_port "${1:-}")"
  info "Removing outside-server network rules for TCP/${port}"
  iptables_del mangle OUTPUT -p tcp --sport "$port" --tcp-flags RST RST -j DROP
  iptables_del raw OUTPUT -p tcp --sport "$port" -j NOTRACK
  iptables_del raw PREROUTING -p tcp --dport "$port" -j NOTRACK
  ok "Firewall rules removed for TCP/${port}"
}

firewall_save() {
  if exists netfilter-persistent; then
    netfilter-persistent save
    ok "Saved with netfilter-persistent."
    return
  fi
  if exists iptables-save; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ok "Saved to /etc/iptables/rules.v4"
    return
  fi
  warn "Could not auto-persist rules. Save them manually for your distro."
}

run_ping() {
  ensure_binary
  [[ -f "$CONFIG_PATH" ]] || die "Config missing: ${CONFIG_PATH}"
  "$BIN_PATH" ping -c "$CONFIG_PATH"
}

run_iface() {
  ensure_binary
  "$BIN_PATH" iface
}

show_secret() {
  printf '%s\n' "$(generate_secret)"
}

backup_config() {
  [[ -f "$CONFIG_PATH" ]] || die "Config missing: ${CONFIG_PATH}"
  ensure_dirs
  local out
  out="${BACKUP_DIR}/config-$(date +%Y%m%d-%H%M%S).yaml"
  cp "$CONFIG_PATH" "$out"
  ok "Backup created: ${out}"
}

show_summary() {
  echo "Script: ${SCRIPT_VERSION}"
  echo "Binary: ${BIN_PATH}"
  if [[ -x "$BIN_PATH" ]]; then
    installed_version || true
  else
    echo "not installed"
  fi
  echo "Config: ${CONFIG_PATH}"
  [[ -f "$CONFIG_PATH" ]] && echo "exists" || echo "missing"
  echo "Service file: ${SERVICE_PATH}"
  [[ -f "$SERVICE_PATH" ]] && echo "exists" || echo "missing"
  if exists systemctl; then
    echo "Service active:"
    systemctl is-active "$SERVICE_NAME" 2>/dev/null || true
  fi
}

edit_config() {
  ensure_dirs
  [[ -f "$CONFIG_PATH" ]] || touch "$CONFIG_PATH"
  local ed="${EDITOR:-nano}"
  if ! exists "$ed"; then ed="vi"; fi
  exists "$ed" || die "No editor found (set EDITOR)."
  "$ed" "$CONFIG_PATH"
}

quick_setup_server() {
  echo
  echo "===== Full setup: Outside server ====="
  echo "Step 1: install binary"
  install_binary
  echo "Step 2: create outside config"
  wizard_server
  echo "Step 3: create system service"
  create_service
  echo "Step 4: apply required network rules"
  firewall_apply
  firewall_save
  echo "Step 5: start service"
  service_restart_or_start
  ok "Outside server setup completed."
}

quick_setup_client() {
  echo
  echo "===== Full setup: Iran server ====="
  echo "Step 1: install binary"
  install_binary
  echo "Step 2: create Iran config"
  wizard_client
  echo "Step 3: create system service"
  create_service
  echo "Step 4: start service"
  service_restart_or_start
  ok "Iran server setup completed."
}

uninstall_all() {
  if ! confirm "Remove paqet binary and service from this server?"; then
    return 0
  fi
  if exists systemctl; then
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
  fi
  rm -f "$SERVICE_PATH"
  exists systemctl && systemctl daemon-reload >/dev/null 2>&1 || true
  rm -f "$BIN_PATH"
  if [[ -d "$ETC_DIR" ]] && confirm "Remove config files in ${ETC_DIR} too?"; then
    rm -rf "$ETC_DIR"
  fi
  ok "Uninstall completed."
}

menu_install() {
  while true; do
    cat <<'EOF'

--- Install ---
1) Install or update paqet
2) Show installed version/status
0) Back
EOF
    local n
    n="$(prompt_default "Select" "1")"
    case "$n" in
      1) install_binary || true ;;
      2) show_summary || true ;;
      0) break ;;
      *) warn "Invalid option." ;;
    esac
  done
}

menu_config() {
  while true; do
    cat <<'EOF'

--- Configure Tunnel ---
1) Full setup outside server (recommended)
2) Full setup Iran server (recommended)
3) Create outside config only
4) Create Iran config only
5) Apply required outside network rules
6) Remove outside network rules
7) Save network rules
8) Show interfaces
9) Generate Shared Key
0) Back
EOF
    local n
    n="$(prompt_default "Select" "1")"
    case "$n" in
      1) quick_setup_server || true ;;
      2) quick_setup_client || true ;;
      3) wizard_server || true ;;
      4) wizard_client || true ;;
      5) firewall_apply || true ;;
      6) firewall_remove || true ;;
      7) firewall_save || true ;;
      8) run_iface || true ;;
      9) show_secret || true ;;
      0) break ;;
      *) warn "Invalid option." ;;
    esac
  done
}

menu_manage() {
  while true; do
    cat <<'EOF'

--- Manage ---
1) Create or recreate service
2) Start
3) Stop
4) Restart
5) Status
6) Show logs
7) Follow logs
8) Ping test
9) Summary
0) Back
EOF
    local n
    n="$(prompt_default "Select" "5")"
    case "$n" in
      1) create_service || true ;;
      2) service_ctl start || true ;;
      3) service_ctl stop || true ;;
      4) service_ctl restart || true ;;
      5) service_status || true ;;
      6) service_logs || true ;;
      7) service_logs_follow || true ;;
      8) run_ping || true ;;
      9) show_summary || true ;;
      0) break ;;
      *) warn "Invalid option." ;;
    esac
  done
}

menu_edit_remove() {
  while true; do
    cat <<'EOF'

--- Edit and Remove ---
1) Edit config file
2) Backup config
3) Full uninstall
0) Back
EOF
    local n
    n="$(prompt_default "Select" "1")"
    case "$n" in
      1) edit_config || true ;;
      2) backup_config || true ;;
      3) uninstall_all || true ;;
      0) break ;;
      *) warn "Invalid option." ;;
    esac
  done
}

show_quick_guide() {
  cat <<'EOF'

===== Very Short Guide =====
Important: all examples are placeholders. Replace with your real values.
Do not type: x.x.x.x, aa:bb:cc:dd:ee:ff, example.com, your-domain.com

1) Run this on outside server:
   sudo ./paqet.sh setup-outside

2) Keep these values from output:
   Server Address and Shared Key

3) Run this on Iran server:
   sudo ./paqet.sh setup-iran
   Enter the same Server Address and Shared Key from step 2.
   In the same setup, add your direct tunnel ports (forward rules).

4) Test on Iran server:
   curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
EOF
}

menu() {
  while true; do
    cat <<'EOF'

====== PAQET EASY MENU ======
1) Install
2) Configure Tunnel
3) Manage
4) Edit and Remove
5) Quick guide (Iran <-> Outside)
0) Exit
EOF
    local n
    n="$(prompt_default "Select" "5")"
    case "$n" in
      1) menu_install || true ;;
      2) menu_config || true ;;
      3) menu_manage || true ;;
      4) menu_edit_remove || true ;;
      5) show_quick_guide ;;
      0) break ;;
      *) warn "Invalid option." ;;
    esac
  done
}

main() {
  local cmd="${1:-menu}"
  case "$cmd" in
    -h|--help|help) usage; exit 0 ;;
  esac

  require_root

  case "$cmd" in
    setup-outside|setup-server) quick_setup_server ;;
    setup-iran|setup-client) quick_setup_client ;;
    install|update) install_binary ;;
    config-outside|wizard-server) wizard_server ;;
    config-iran|wizard-client) wizard_client ;;
    service-create) create_service ;;
    start) service_ctl start ;;
    stop) service_ctl stop ;;
    restart) service_ctl restart ;;
    status) service_status ;;
    logs) service_logs "${2:-120}" ;;
    logs-follow) service_logs_follow ;;
    net-prepare|firewall-apply) firewall_apply "${2:-}" ;;
    net-clean|firewall-remove) firewall_remove "${2:-}" ;;
    net-save|firewall-save) firewall_save ;;
    ping) run_ping ;;
    iface) run_iface ;;
    secret) show_secret ;;
    backup-config) backup_config ;;
    quick-guide) show_quick_guide ;;
    edit-config) edit_config ;;
    show) show_summary ;;
    uninstall) uninstall_all ;;
    menu) menu ;;
    *)
      die "Unknown command: ${cmd}. Use --help."
      ;;
  esac
}

main "$@"
