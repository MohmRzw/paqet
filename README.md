# راهنمای سریع و واضح نصب Paqet (Outside -> Iran)

این راهنما برای ساده‌ترین راه‌اندازی نوشته شده: کمترین خطا، کمترین ابهام.

## 1) یک دستور نصب برای هر دو سرور

روی **هر دو سرور** (خارج و ایران) همین دستور را اجرا کن:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash
```

---

## 2) نقشه خیلی کوتاه راه‌اندازی

1. روی سرور **خارج**: گزینه `outside-easy`
2. از خروجی خارج: `Server Address` و `Shared Key` را بردار
3. روی سرور **ایران**: گزینه `iran-easy` و همان دو مقدار را وارد کن

---

## 3) خیلی مهم: هر IP را کجا وارد کنم؟

| محل | چه چیزی باید وارد شود | مثال |
|---|---|---|
| خارج | `Local IPv4 of this outside server` = آی‌پی خود خارج | `10.0.0.10` |
| ایران | `[REQUIRED] Outside server address` = آی‌پی/دامنه خارج + پورت تونل | `5.75.197.42:9999` |
| ایران | `Local IPv4 of this Iran server` = آی‌پی خود ایران | `10.10.10.20` |
| ایران (Forward) | `Bulk target host/domain` یا `Target via tunnel` = مقصد سرویس | `5.75.197.42` |

خلاصه:
- آی‌پی **خارج** را روی **ایران** وارد می‌کنی.
- آی‌پی **ایران** را فقط به عنوان Local IPv4 خودش وارد می‌کنی.

---

## 4) مسیر پیشنهادی (خیلی ساده)

### مرحله A) خارج

1. دستور نصب را اجرا کن.
2. در منو `outside-easy` را انتخاب کن.
3. این دو مقدار را ذخیره کن:
   - `Server Address` (مثال: `5.75.197.42:9999`)
   - `Shared Key`

### مرحله B) ایران

1. دستور نصب را اجرا کن.
2. در منو `iran-easy` را انتخاب کن.
3. وارد کن:
   - `Outside server address`: مثل `5.75.197.42:9999`
   - `Shared Key`: همان کلید خارج

پیش‌فرض `iran-easy`:
- SOCKS: `0.0.0.0:1080`
- Forward target: host سرور خارج
- Forward ports: `443,8443`

---

## 5) Full Wizard Prompts (English)

<details>
<summary><b>Outside Server - Full Wizard (<code>outside</code>)</b></summary>

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

</details>

<details>
<summary><b>Iran Server - Full Wizard (<code>iran</code>)</b></summary>

| Prompt | Example answer |
|---|---|
| `Use detected values?` | `Y` |
| `Network interface name (example: eth0 or ens3)` | `eth0` *(asked if previous answer was `N`)* |
| `Gateway IPv4 (optional, example: 192.168.1.1)` | `192.168.1.1` *(optional)* |
| `Local IPv4 of this Iran server (example: 10.10.10.20)` | `10.10.10.20` |
| `Router MAC (example: 12:34:56:78:9a:bc, do not use aa:bb:cc:dd:ee:ff)` | `12:34:56:78:9a:bc` |
| `[REQUIRED] Outside server address (example: 203.0.113.10:9999, do not type x.x.x.x)` | `5.75.197.42:9999` |
| `Enable local SOCKS5 for apps?` | `Y` |
| `Expose SOCKS5 on all interfaces (0.0.0.0)?` | `Y` *(or `N`)* |
| `Local SOCKS5 address (example: 0.0.0.0:1080 or 127.0.0.1:1080)` | `0.0.0.0:1080` |
| `Use TCP/<PORT> anyway?` | `y` or `n` *(only if SOCKS port is in use)* |
| `Enable username/password for local SOCKS5?` | `N` *(or `Y`)* |
| `Username (example: myuser)` | `myuser` *(only if auth enabled)* |
| `Password (example: mypass123)` | `mypassword123` *(only if auth enabled)* |
| `Add direct app ports now (forward rules)?` | `Y` |
| `Expose forward ports on all interfaces (0.0.0.0)?` | `Y` |
| `Use BULK input (comma-separated ports)?` | `Y` *(recommended)* |
| `Bulk target host/domain (example: 93.184.216.34 or your-real-domain.com)` | `5.75.197.42` |
| `Bulk local listen IP (example: 0.0.0.0 or 127.0.0.1)` | `0.0.0.0` |
| `Bulk protocol for all rules (tcp/udp)` | `tcp` |
| `Bulk ports list (example: 7001,7002 or 7001:443,7002:8443)` | `443,8443` |
| `Add another bulk list?` | `n` |
| `[REQUIRED] Shared Key (same as outside server, do not type shared-key)` | `8a5e2db0f0b0d3f8e8e4f0d84cc713df8a2e9d0f7f2e53a8b3c1d2e4f5a6b7c8` |
| `Log level (example: info)` | `info` |
| `Overwrite /etc/paqet/config.yaml?` | `y` *(only if config already exists)* |

</details>

<details>
<summary><b>Easy Mode Prompts (English)</b></summary>

`outside-easy`:
- Usually no questions (auto-detect + defaults).

`iran-easy`:
- `[REQUIRED] Outside server address (example: 203.0.113.10:9999)`
- `[REQUIRED] Shared Key (same as outside server)`

</details>

---

## 6) تست سریع نهایی

روی ایران:

```bash
systemctl --no-pager -l status paqet | sed -n '1,40p'
ss -lntp | egrep ':1080|:443|:8443'
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

---

## 7) اگر کار نکرد

اول تداخل پورت را چک کن:

```bash
ss -lntp | egrep ':443|:8443'
```

اگر این پورت‌ها دست سرویس دیگری باشند، فوروارد همان پورت‌ها عمل نمی‌کند.
