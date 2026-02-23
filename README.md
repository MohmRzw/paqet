# راهنمای نصب Paqet

## نصب (برای هر دو سرور)

روی سرور خارج و ایران فقط همین دستور را اجرا کن:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash
```

## ترتیب اجرا

1. اول روی سرور خارج نصب و کانفیگ انجام بده.
2. `Server Address` و `Shared Key` را بردار.
3. بعد روی سرور ایران نصب و کانفیگ انجام بده.

---

## سوالات نصب (English Guide)

### 0) Installer Menu (shown after install command)

| Prompt | Example answer |
|---|---|
| `Select [1]:` | `3` for full Outside wizard, `4` for full Iran wizard |

Menu options:
- `1) outside-easy`
- `2) iran-easy`
- `3) outside (full wizard)`
- `4) iran (full wizard)`
- `5) menu`

---

### 1) Outside Server - Full Wizard (`outside`)

| Prompt | Example answer |
|---|---|
| `Use detected values?` | `Y` |
| `Network interface name (example: eth0 or ens3)` | `eth0` *(asked if previous answer was `N`)* |
| `Gateway IPv4 (optional, example: 192.168.1.1)` | `192.168.1.1` *(optional)* |
| `Local IPv4 of this outside server (example: 10.0.0.10)` | `10.0.0.10` |
| `Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)` | `12:34:56:78:9a:bc` |
| `Tunnel port on outside server (example: 9999)` | `9999` *(or `443` / `8443`)* |
| `Use TCP/<PORT> anyway?` | `y` or `n` *(only if port is already in use)* |
| `Shared Key (example format: 64 hex chars, do not type shared-key)` | `8a5e2db0f0b0d3f8e8e4f0d84cc713df8a2e9d0f7f2e53a8b3c1d2e4f5a6b7c8` |
| `Log level (example: info)` | `info` |
| `Overwrite /etc/paqet/config.yaml?` | `y` *(only if config already exists)* |

Expected output to save:
- `Server Address` example: `5.75.197.42:9999`
- `Shared Key` example: same key above

---

### 2) Iran Server - Full Wizard (`iran`)

| Prompt | Example answer |
|---|---|
| `Use detected values?` | `Y` |
| `Network interface name (example: eth0 or ens3)` | `eth0` *(asked if previous answer was `N`)* |
| `Gateway IPv4 (optional, example: 192.168.1.1)` | `192.168.1.1` *(optional)* |
| `Local IPv4 of this Iran server (example: 10.10.10.20)` | `10.10.10.20` |
| `Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)` | `12:34:56:78:9a:bc` |
| `[REQUIRED] Outside server address (example: 203.0.113.10:9999, do not type x.x.x.x)` | `5.75.197.42:9999` |
| `Enable local SOCKS5 for apps?` | `Y` |
| `Expose SOCKS5 on all interfaces (0.0.0.0)?` | `Y` *(or `N` for local-only)* |
| `Local SOCKS5 address (example: 0.0.0.0:1080 or 127.0.0.1:1080)` | `0.0.0.0:1080` |
| `Use TCP/<PORT> anyway?` | `y` or `n` *(only if SOCKS port is in use)* |
| `Enable username/password for local SOCKS5?` | `N` *(or `Y`)* |
| `Username (example: myuser)` | `myuser` *(only if auth enabled)* |
| `Password (example: mypass123)` | `mypassword123` *(only if auth enabled)* |
| `Add direct app ports now (forward rules)?` | `Y` |
| `Expose forward ports on all interfaces (0.0.0.0)?` | `Y` |
| `Use BULK input (comma-separated ports)?` | `Y` *(recommended)* |

If BULK is `Y`:

| Prompt | Example answer |
|---|---|
| `Bulk target host/domain (example: 93.184.216.34 or your-real-domain.com)` | `5.75.197.42` |
| `Bulk local listen IP (example: 0.0.0.0 or 127.0.0.1)` | `0.0.0.0` |
| `Bulk protocol for all rules (tcp/udp)` | `tcp` |
| `Bulk ports list (example: 7001,7002 or 7001:443,7002:8443)` | `443,8443` |
| `Add another bulk list?` | `n` |

If BULK is `N` (manual mode):

| Prompt | Example answer |
|---|---|
| `Local listen address (example: 0.0.0.0:7001)` | `0.0.0.0:443` |
| `Target via tunnel (example: 93.184.216.34:443 or your-domain.com:443)` | `5.75.197.42:443` |
| `Protocol (example: tcp)` | `tcp` |
| `Use TCP/UDP/<PORT> anyway?` | `y` or `n` *(only if local port is in use)* |
| `Add another forward rule?` | `y` / `n` |

Final prompts:

| Prompt | Example answer |
|---|---|
| `[REQUIRED] Shared Key (same as outside server, do not type shared-key)` | `8a5e2db0f0b0d3f8e8e4f0d84cc713df8a2e9d0f7f2e53a8b3c1d2e4f5a6b7c8` |
| `Log level (example: info)` | `info` |
| `Overwrite /etc/paqet/config.yaml?` | `y` *(only if config already exists)* |

---

### 3) Easy Mode Questions (for completeness)

#### `outside-easy`
- Usually no questions (auto-detect + defaults).

#### `iran-easy`

| Prompt | Example answer |
|---|---|
| `[REQUIRED] Outside server address (example: 203.0.113.10:9999)` | `5.75.197.42:9999` |
| `[REQUIRED] Shared Key (same as outside server)` | `8a5e2db0f0b0d3f8e8e4f0d84cc713df8a2e9d0f7f2e53a8b3c1d2e4f5a6b7c8` |
