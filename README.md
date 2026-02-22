# اسکریپت نصب آسان Paqet (ایران ↔ خارج)

این ریپو **خودِ پروژه paqet نیست**.  
ما فقط یک اسکریپت نصب/مدیریت نوشته‌ایم تا راه‌اندازی `paqet` ساده شود.

## این پروژه دقیقاً چه کاری می‌کند؟

- با `install.sh` اسکریپت اصلی (`paqet.sh`) را روی سرور نصب می‌کند.
- با `paqet.sh` مراحل نصب، کانفیگ، سرویس و اجرای تانل را ساده می‌کند.
- باینری اصلی `paqet` را از ریلیز رسمی `hanselime/paqet` دانلود می‌کند.

## نصب سریع (فقط دو دستور)

> ترتیب درست: اول خارج، بعد ایران

### 1) سرور خارج (اول)

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- --repo MohmRzw/paqet outside
```

### 2) سرور ایران (دوم)

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- --repo MohmRzw/paqet iran
```

بعد از اجرای دستور خارج، این دو مقدار را نگه دارید و در ایران وارد کنید:

- `Server Address`
- `Shared Key`

## ورودی‌ها را چطور وارد کنیم؟

- مثال‌ها فقط نمونه‌اند.
- مقادیر نمونه را عیناً وارد نکنید.
- این‌ها نباید عیناً تایپ شوند:
  - `x.x.x.x`
  - `aa:bb:cc:dd:ee:ff`
  - `example.com`
  - `your-domain.com`

## پورت‌هایی که می‌خواهید تانل شوند

در مرحله `iran`، اسکریپت خودش می‌پرسد:

- آیا `SOCKS5` می‌خواهید یا نه
- آیا `forward` می‌خواهید یا نه
- اگر `forward` بزنید، برای هر Rule می‌پرسد:
  - `Local listen` (مثل `127.0.0.1:7001`)
  - `Target` (مثل `1.2.3.4:443` یا `your-real-domain.com:443`)
  - `Protocol` (`tcp` یا `udp`)

یعنی دیگر نیازی نیست حتماً دستی فایل کانفیگ را ادیت کنید.

## تست سریع بعد از نصب

اگر SOCKS روشن باشد (مثلاً `127.0.0.1:1080`) روی ایران تست کنید:

```bash
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

اگر IP خروجی، IP سرور خارج بود یعنی تانل برقرار است.

## مدیریت بعد از نصب

```bash
sudo /usr/local/bin/paqet-manager menu
```

یا مستقیم:

```bash
sudo /usr/local/bin/paqet-manager status
sudo /usr/local/bin/paqet-manager logs 100
sudo /usr/local/bin/paqet-manager restart
```
