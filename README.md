# راهنمای خیلی ساده و کامل Paqet (خارج -> ایران)

این ریپو خود هسته `paqet` نیست؛ یک منیجر نصب/کانفیگ است که راه‌اندازی را خیلی سریع‌تر می‌کند.

## 1) یک دستور نصب برای هر دو سرور

هم روی خارج و هم روی ایران فقط همین یک دستور:

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash
```

بعد از اجرا این منو را می‌بینی:

1. `outside-easy` (پیشنهادی برای خارج)
2. `iran-easy` (پیشنهادی برای ایران)
3. `outside` (ویزارد کامل)
4. `iran` (ویزارد کامل)
5. `menu`

## 2) ترتیب درست راه‌اندازی

1. اول خارج را بساز.
2. `Server Address` و `Shared Key` را بردار.
3. بعد ایران را با همان مقادیر بساز.

---

## مرحله 1: راه‌اندازی سرور خارج (Kharej / Server)

### روش پیشنهادی و سریع

1. دستور نصب بالا را روی خارج بزن.
2. از منو گزینه `1` یا `outside-easy` را انتخاب کن.
3. اگر پورت نداد‌ه باشی، پیش‌فرض `9999` می‌گذارد.
4. اگر کلید نداده باشی، Secret خودکار تولید می‌کند.
5. در انتها این دو مقدار را ذخیره کن:
   - `Server Address` مثل `5.75.197.42:9999`
   - `Shared Key`

اگر بعدا این مقادیر را گم کردی:

```bash
sudo /usr/local/bin/paqet-manager show-iran-cmd
```

### روش کامل (مطابق سبک مرحله‌ای)

اگر جزئیات کامل می‌خواهی، از منو گزینه `3` یا `outside`:

1. `Use detected values?` -> معمولا `Y`
2. `Tunnel port on outside server` -> مثلا `443` یا `8443` یا `9999`
3. `Shared Key` -> Enter برای تولید خودکار یا دستی وارد کن
4. `Log level` -> پیش‌فرض `info`

اسکریپت خودش:
- باینری را نصب/آپدیت می‌کند
- سرویس `systemd` می‌سازد
- رول‌های لازم خارج را اعمال و ذخیره می‌کند
- سرویس را بالا می‌آورد

---

## مرحله 2: راه‌اندازی سرور ایران (Iran / Client Entry Point)

### روش پیشنهادی و سریع

1. همان دستور نصب را روی ایران بزن.
2. از منو گزینه `2` یا `iran-easy` را انتخاب کن.
3. فقط این مقادیر اصلی را بده:
   - `Outside server address` -> مثلا `5.75.197.42:9999`
   - `Shared Key` -> همان کلید خارج

پیش‌فرض‌های `iran-easy`:
- SOCKS5 روی `0.0.0.0:1080`
- Forward listen روی `0.0.0.0`
- پورت‌های فوروارد `443,8443`
- Target host همان host سرور خارج

### روش کامل (مطابق همان فرمتی که خواستی)

اگر ویزارد کامل می‌خواهی، از منو گزینه `4` یا `iran`:

1. `Use detected values?` -> `Y`
2. `[REQUIRED] Outside server address` -> `5.75.197.42:9999`
3. `Enable local SOCKS5 for apps?` -> `Y`
4. `Expose SOCKS5 on all interfaces (0.0.0.0)?` -> `Y` (اگر کلاینت بیرونی داری)
5. `Enable username/password for local SOCKS5?` -> در صورت نیاز `Y`
6. `Add direct app ports now (forward rules)?` -> `Y`
7. `Expose forward ports on all interfaces (0.0.0.0)?` -> `Y`
8. `Use BULK input (comma-separated ports)?` -> `Y`
9. `Bulk target host/domain` -> `5.75.197.42`
10. `Bulk local listen IP` -> `0.0.0.0`
11. `Bulk protocol` -> `tcp`
12. `Bulk ports list` -> `443,8443` (یا مثلا `333,394,395`)
13. `Add another bulk list?` -> `n`
14. `[REQUIRED] Shared Key` -> همان کلید خارج
15. `Log level` -> `info`

---

## 3) نصب بدون منو (اختیاری)

### خارج

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- outside-easy
```

### ایران

```bash
curl -fsSL https://raw.githubusercontent.com/MohmRzw/paqet/main/install.sh | sudo bash -s -- iran-easy --server 5.75.197.42:9999 --key YOUR_SHARED_KEY --target 5.75.197.42 --ports 443,8443
```

---

## 4) تست سریع بعد از راه‌اندازی

روی ایران:

```bash
systemctl --no-pager -l status paqet | sed -n '1,40p'
ss -lntp | egrep ':1080|:443|:8443'
journalctl -u paqet -n 80 --no-pager
```

تست SOCKS:

```bash
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

اگر `origin` برابر IP خارج بود، تونل سالم است.

تست پورت‌ها:

```bash
nc -vz 127.0.0.1 443
nc -vz 127.0.0.1 8443
```

---

## 5) مدیریت سرویس

```bash
sudo /usr/local/bin/paqet-manager status
sudo /usr/local/bin/paqet-manager logs 120
sudo /usr/local/bin/paqet-manager restart
sudo /usr/local/bin/paqet-manager menu
```

