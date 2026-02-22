# PAQET Easy Installer

Easy one-command bootstrap for Iran <-> Outside tunnel setup using `paqet.sh`.

## 1) Put this on GitHub

Create a GitHub repo and upload these files:

- `paqet.sh`
- `install.sh`
- `README.md`
- `.gitignore`

Suggested branch: `main`

## 2) One-command install and run

Use your repo path in `REPO` (example: `myuser/paqet`).

### Outside server (run first)

```bash
REPO="myuser/paqet"; sudo bash <(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install.sh") --repo "$REPO" outside
```

### Iran server (run second)

```bash
REPO="myuser/paqet"; sudo bash <(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/install.sh") --repo "$REPO" iran
```

This flow is one-shot:

1. `outside` installs + configures + starts outside side
2. `iran` installs + configures + starts Iran side
3. During Iran setup, it asks for forward ports directly (no manual config edit required)

## 3) Important input note

Examples shown by the script are placeholders.
Do **not** type literals like:

- `x.x.x.x`
- `aa:bb:cc:dd:ee:ff`
- `example.com`
- `your-domain.com`

Enter your real values.

## 4) Quick verify on Iran server

If SOCKS is enabled (`127.0.0.1:1080`):

```bash
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

If IP returned is the outside server IP, tunnel is working.
