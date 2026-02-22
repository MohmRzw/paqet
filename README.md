# اسکریپت نصب آسان Paqet (ایران ↔ خارج)

این ریپو **خودِ پروژه paqet نیست**.  
ما فقط یک اسکریپت نصب/مدیریت نوشته‌ایم تا راه‌اندازی `paqet` ساده‌تر شود.

هسته و باینری اصلی همچنان از پروژه رسمی `hanselime/paqet` دریافت می‌شود.

## روش پیشنهادی: اول با منو (هم برای خارج، هم برای ایران)

اگر می‌خواهید مرحله‌به‌مرحله جلو بروید، اول منو را بالا بیاورید:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- --repo MohmRzw/paqet menu
```

در منو این مسیر را بزنید:

1. `Configure Tunnel`
2. روی سرور خارج: `Full setup outside server (recommended)`
3. روی سرور ایران: `Full setup Iran server (recommended)`

نکته: همین یک دستور `menu` را می‌توانید هم روی خارج و هم روی ایران اجرا کنید.

## نصب آسان مستقیم (بدون منو)

> ترتیب درست: اول خارج، بعد ایران

### 1) سرور خارج (اول)

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- --repo MohmRzw/paqet outside
```

### 2) سرور ایران (دوم)

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- --repo MohmRzw/paqet iran
```

بعد از نصب خارج، این دو مقدار را نگه دارید و در ایران وارد کنید:

- `Server Address`
- `Shared Key`

## ورودی‌های لازم و پیش‌فرض‌ها

- بیشتر ورودی‌ها Default دارند و با Enter رد می‌شوند.
- فقط گزینه‌هایی که با `[REQUIRED]` نمایش داده می‌شوند باید دستی وارد شوند.
- مثال‌ها فقط نمونه‌اند؛ عیناً وارد نکنید.

این مقادیر را نباید عیناً تایپ کنید:

- `x.x.x.x`
- `aa:bb:cc:dd:ee:ff`
- `example.com`
- `your-domain.com`

## پورت‌هایی که می‌خواهید تانل شوند (Forward)

در مرحله `iran`، اسکریپت می‌پرسد:

- آیا `SOCKS5` می‌خواهید یا نه
- آیا `forward` می‌خواهید یا نه
- آیا می‌خواهید پورت‌ها را به صورت **Bulk** وارد کنید یا نه

اگر Bulk را بزنید، می‌توانید چند پورت را یکجا با `,` وارد کنید:

- حالت ساده (local و target یکسان): `7001,7002,7003`
- حالت mapping (local:target): `7001:443,7002:8443,7003:9443`

در Bulk فقط یک بار Host و Protocol می‌دهید و بقیه Ruleها خودکار ساخته می‌شود.

## تست سریع بعد از نصب

اگر SOCKS فعال است (مثلا `127.0.0.1:1080`) روی ایران تست کنید:

```bash
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

اگر IP خروجی، IP سرور خارج بود یعنی تانل برقرار است.

## مدیریت بعد از نصب

منو:

```bash
sudo /usr/local/bin/paqet-manager menu
```

دستورات مستقیم:

```bash
sudo /usr/local/bin/paqet-manager status
sudo /usr/local/bin/paqet-manager logs 100
sudo /usr/local/bin/paqet-manager restart
```
