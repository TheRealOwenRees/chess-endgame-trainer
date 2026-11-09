# Static coming-soon page

A self-contained branding page for the domain while the gated app (#116) and
mail delivery (#84) are still outstanding. It needs no BEAM, no database, no
newsletter form, and no JavaScript — just static files and Caddy.

```
deploy/static/
├── index.html      # page + inline CSS; uses the app's real brand tokens
├── fonts/          # DM Sans + DM Serif Display woff2 files
├── favicon.ico     # copied from priv/static
├── Caddyfile       # site block template; rendered by deploy.sh --caddy
├── deploy.sh       # upload files; optional marked Caddy block
└── README.md
```

## Preview locally

```sh
python3 -m http.server 8080 --directory deploy/static
# open http://localhost:8080
```

The page is deliberately light-only — it uses the brand's paper palette
regardless of the visitor's OS theme. It references `/fonts/...` and
`/favicon.ico` from the site root, so preview it at the root (as above), not
by opening `index.html` directly.

## One-time VPS setup

1. **DNS** — point an `A` record (and `AAAA` if you have IPv6) for the domain
   and `www` at the VPS.
2. **SSH user** — the deploy user needs passwordless `sudo` for the commands in
   `deploy.sh`, or use your normal sudo-capable user (`VPS_USER=ubuntu`).
3. **Firewall** — allow SSH, 80 and 443. With UFW:

   ```sh
   sudo ufw allow OpenSSH
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

   Also open 80/443 in your provider's security group if you have one.
4. **Caddy** — install from the official apt repository:

   ```sh
   sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
   curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
     | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
   curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
     | sudo tee /etc/apt/sources.list.d/caddy-stable.list
   sudo apt update
   sudo apt install -y caddy
   sudo systemctl enable --now caddy
   ```

   Caddy obtains and renews the TLS certificate automatically once DNS points
   at the VPS and ports 80/443 are reachable.

## Deploy

### Files only (default)

Use this when the site block is already in your Caddy config. The script
uploads the files and **never touches Caddy**.

```sh
VPS_HOST=203.0.113.10 VPS_USER=ubuntu ./deploy/static/deploy.sh
```

Re-run this to update the page.

### Let the script manage the Caddy block (`--caddy`)

Pass `--caddy` and a `SITE_ADDRESS` to have the script add or update the site
block:

```sh
SITE_ADDRESS="innersquarechess.com, www.innersquarechess.com" \
VPS_HOST=203.0.113.10 \
VPS_USER=ubuntu \
./deploy/static/deploy.sh --caddy
```

The script edits only the region between these markers in `REMOTE_CADDYFILE`
(default `/etc/caddy/Caddyfile`):

```caddyfile
# BEGIN innersquare-coming-soon (managed by deploy/static/deploy.sh)
...
# END innersquare-coming-soon
```

It backs up the file, validates the whole config, restores the backup if
validation fails, and reloads Caddy. If the domain already appears in the file
**without** the markers — for example, a block added by hand — it refuses to
touch the file rather than risk duplicating the site.

### Single shared Caddyfile

If all your server blocks live in `/etc/caddy/Caddyfile` and the innersquare
block is already there, use the default files-only mode. Don't run `--caddy`
unless you remove the manual block first and want the script to own it.

### Dedicated file / import

You can point `REMOTE_CADDYFILE` at a dedicated file and add one import line to
the main Caddyfile:

```sh
REMOTE_CADDYFILE=/etc/caddy/conf.d/innersquare.caddy \
SITE_ADDRESS=innersquarechess.com \
VPS_HOST=203.0.113.10 \
VPS_USER=ubuntu \
./deploy/static/deploy.sh --caddy
```

```caddyfile
import /etc/caddy/conf.d/*.caddy
```

Optional overrides: `SSH_PORT`, `WEB_ROOT` (default `/var/www/innersquare`),
`REMOTE_CADDYFILE` (default `/etc/caddy/Caddyfile`).

## What this page deliberately does not do

- **No newsletter signup** — that waits on real mail delivery (#84) and the
  gated app (#116).
- **No analytics, cookies, or JavaScript.**
- **No indexing** — `robots.txt` is absent and Caddy sends
  `X-Robots-Tag: noindex, nofollow` plus the page has a robots meta tag.

## Replacing it later

When the Phoenix release lands (#117), either point Caddy's reverse proxy at
the app or remove this Caddy site block. Keep the static page around as an
instant fallback if a deploy goes wrong.
