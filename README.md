# PAQET Manager (FA / EN)

Simple installer/manager for running `paqet` between **Outside (Server)** and **Iran (Client)**.

---

## FA

### نصب (برای هر دو سرور)

روی هر دو سرور همین دستور را اجرا کن:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash
```

### راه‌اندازی سریع

1. اول روی سرور خارج `outside-easy` را انتخاب کن.
2. `Server Address` و `Shared Key` را ذخیره کن.
3. بعد روی سرور ایران `iran-easy` را انتخاب کن و همان مقادیر را وارد کن.

### نصب بدون منو (اختیاری)

خارج:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside-easy
```

ایران:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- iran-easy --server 5.75.197.42:9999 --key YOUR_SHARED_KEY --target 5.75.197.42 --ports 443,8443
```

### تست سریع

```bash
systemctl --no-pager -l status paqet | sed -n '1,40p'
ss -lntp | egrep ':1080|:443|:8443'
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

### مدیریت سرویس

```bash
sudo /usr/local/bin/paqet-manager status
sudo /usr/local/bin/paqet-manager logs 120
sudo /usr/local/bin/paqet-manager restart
sudo /usr/local/bin/paqet-manager menu
```

### نکته مهم

- اگر پورت `443` یا `8443` قبلا توسط سرویس دیگری اشغال باشد، فوروارد کار نمی‌کند:

```bash
ss -lntp | egrep ':443|:8443'
```

---

## EN

### Install (same command on both servers)

Run this on both Outside and Iran servers:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash
```

### Quick Setup

1. On Outside server, choose `outside-easy`.
2. Save `Server Address` and `Shared Key`.
3. On Iran server, choose `iran-easy` and enter the same values.

### No-menu mode (optional)

Outside:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside-easy
```

Iran:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- iran-easy --server 5.75.197.42:9999 --key YOUR_SHARED_KEY --target 5.75.197.42 --ports 443,8443
```

### Quick Check

```bash
systemctl --no-pager -l status paqet | sed -n '1,40p'
ss -lntp | egrep ':1080|:443|:8443'
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

### Service Commands

```bash
sudo /usr/local/bin/paqet-manager status
sudo /usr/local/bin/paqet-manager logs 120
sudo /usr/local/bin/paqet-manager restart
sudo /usr/local/bin/paqet-manager menu
```

### Important

- If `443`/`8443` is already in use by another service, forwarding will fail:

```bash
ss -lntp | egrep ':443|:8443'
```
