# راهنمای ساده Paqet (خارج -> ایران)

این ریپو خود پروژه `paqet` نیست؛ یک اسکریپت مدیریت و نصب ساده برای راه‌اندازی سریع است.

## 1) نصب کلی با یک دستور

روی هر سرور (خارج یا ایران) همین دستور را بزن:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash
```

بعد از اجرا، از منو نوع سرور را انتخاب کن:
- روی سرور خارج: `outside`
- روی سرور ایران: `iran`

## 2) ترتیب درست راه‌اندازی

1. اول روی **سرور خارج** setup انجام بده.
2. خروجی `Server Address` و `Shared Key` را بردار.
3. بعد روی **سرور ایران** setup انجام بده و همان مقادیر را وارد کن.

## 3) تنظیم دقیق سرور خارج (مرحله اول)

اگر نمی‌خواهی منو بیاید، مستقیم بزن:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside
```

در سوال‌ها:
- `Tunnel port`: مثلا `9999` (پیشنهادی)
- `Shared Key`: یک مقدار قوی (اسکریپت خودش هم می‌سازد)

در پایان این دو مقدار را ذخیره کن:
- `Server Address` (مثال: `5.75.197.42:9999`)
- `Shared Key`

## 4) تنظیم دقیق سرور ایران (مرحله دوم)

اگر نمی‌خواهی منو بیاید، مستقیم بزن:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- iran
```

### نمونه ورودی واقعی (برای فوروارد 443 و 8443)

این مقادیر را وارد کن:

- `[REQUIRED] Outside server address`:  
  `5.75.197.42:9999`
- `[REQUIRED] Shared Key`:  
  همان Shared Key سرور خارج
- `Enable local SOCKS5 for apps?`  
  اگر لازم داری: `y`
- `Expose SOCKS5 on all interfaces (0.0.0.0)?`  
  اگر کلاینت از سرور دیگر وصل می‌شود: `y`  
  اگر فقط روی همان ماشین ایران استفاده می‌کنی: `n`
- `Add direct app ports now (forward rules)?`  
  `y`
- `Expose forward ports on all interfaces (0.0.0.0)?`  
  برای دسترسی از بیرون: `y`
- `Use BULK input (comma-separated ports)?`  
  `y`
- `Bulk target host/domain`  
  `5.75.197.42`
- `Bulk local listen IP`  
  `0.0.0.0`
- `Bulk protocol`  
  `tcp`
- `Bulk ports list`  
  `443,8443`
- `Add another bulk list?`  
  `n`

## 5) تست سریع بعد از راه‌اندازی

### روی ایران

بررسی اینکه پورت‌ها واقعاً روی آدرس درست باز هستند:

```bash
ss -lntp | egrep ':1080|:443|:8443'
systemctl --no-pager -l status paqet | sed -n '1,40p'
journalctl -u paqet -n 80 --no-pager
```

تست SOCKS (اگر فعالش کردی):

```bash
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

اگر `origin` برابر IP خارج بود، تونل درست است.

### تست فوروارد

از کلاینتی که می‌خواهد وصل شود:
- به `IRAN_IP:443`
- یا `IRAN_IP:8443`

نکته: اگر خروجی `HTTP/2 415 grpc` دیدی، معمولاً یعنی مسیر تا سرویس مقصد رسیده و مشکل از نوع درخواست (curl ساده) است، نه خود تونل.

## 6) دستورات مدیریت

```bash
sudo /usr/local/bin/paqet-manager status
sudo /usr/local/bin/paqet-manager logs 120
sudo /usr/local/bin/paqet-manager restart
sudo /usr/local/bin/paqet-manager menu
```

## 7) خطای رایج

- اگر روی ایران سرویس دیگری (مثل xray/nginx) روی `443` یا `8443` گوش می‌دهد، فوروارد همان پورت‌ها کار نمی‌کند.
- با این دستور چک کن:

```bash
ss -lntp | egrep ':443|:8443'
```

اگر پروسه دیگری این پورت‌ها را گرفته، یا آن را جابه‌جا کن یا برای paqet پورت آزاد انتخاب کن.
