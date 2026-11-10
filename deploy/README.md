# Production deployment

Phoenix release on the shared Ubuntu VPS, behind Caddy, with Postgres in Docker.

```text
Internet
  └─ Caddy :443
       └─ Phoenix release 127.0.0.1:4100
            └─ Postgres 127.0.0.1:5432
```

## Pinned versions

| Thing | Version |
|---|---|
| OS | Ubuntu 24.04.5 LTS, x86_64 |
| glibc | 2.39 |
| Erlang | 28.5 |
| Elixir | 1.19.5-otp-28 |
| Rust | 1.98.1 |
| Node.js | 24 (asset build only) |
| Postgres | `postgres:18.6`, pinned directly in the unified compose |
| Caddy | 2.11.9 |
| Docker | 29.9.3 |
| Docker Compose | v5.7.0 |
| GitHub runner | `ubuntu-24.04` |

The release ships its own ERTS. The host needs the runtime libraries for the
Rust NIF (`libstdc++6`), OpenSSL, and CA certificates.

## Host prerequisites

A new Ubuntu 24.04 VPS needs:

- Docker Engine and the Compose plugin
- Caddy
- `curl`, `ca-certificates`, `libstdc++6`, `openssl`
- Node.js 24 + npm if you build the release on this host instead of CI
- DNS and TLS for the domain
- A non-root deploy user with SSH access

Install the host libraries:

```sh
sudo apt update
sudo apt install -y curl ca-certificates libstdc++6 openssl
```

Install Docker and Caddy from their official repositories. The Caddy install
commands already used for the static site are in `deploy/static/README.md`.

Firewall:

```sh
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

Do **not** open `4100` or `5432`. Phoenix binds to loopback, and Postgres is
published only on `127.0.0.1`.

DNS:

- `A`/`AAAA` for `innersquare.app` and `www` point at the VPS.
- Do not remove the existing mail records:
  - root MX records for `support@innersquare.app`
  - SES DKIM CNAMEs
  - the `mail.innersquare.app` custom MAIL FROM MX/TXT records
  - DMARC at `_dmarc.innersquare.app`

## Shared-host choices

- **Port 4100** is used for Phoenix because another BEAM process already owns
  `4000` on this VPS.
- **Postgres runs as `chesstrainer-db`** in the VPS's unified
  `docker-compose.yml` on `127.0.0.1:5432`; that port is free. The image
  version is pinned directly in that file.
- **Caddy is shared and managed manually.** This repo ships a reference block
  in `deploy/Caddyfile`; it is never installed automatically.
- The Postgres volume is named `chesstrainer_pgdata`, so it cannot collide with
  other Docker projects.

## Directory layout

```text
/opt/chesstrainer/
├── releases/
│   ├── 20261109120000/
│   └── 20261109153000/
├── current -> releases/20261109153000
└── src/                 # optional checkout of this repo / deploy scripts
```

`/etc/chesstrainer/env` is the application environment file, owned by
`root:root` with mode `0600`.

`/etc/chesstrainer/postgres.env` holds the Postgres container credentials,
also `root:root` and `0600`.

The app runs as the dedicated `chesstrainer` system user. It must own
`/opt/chesstrainer` so it can write `priv/static/backups`.

## Copy the deploy artifacts

Run these commands from a checkout of this repo on the VPS, or copy the
`deploy/` directory to `/opt/chesstrainer/src/deploy`.

```sh
sudo install -d -o root -g root /opt/chesstrainer/src/deploy
sudo cp -a deploy/. /opt/chesstrainer/src/deploy/
```

If you prefer to keep the checkout elsewhere, use that path in the commands
below.

## Application env file

`/etc/chesstrainer/env`:

```sh
SECRET_KEY_BASE=...
DATABASE_URL=ecto://chesstrainer:...@127.0.0.1:5432/chesstrainer_prod
PHX_HOST=innersquare.app
PORT=4100
POOL_SIZE=10
TRUST_FORWARDED_FOR=true

PRELAUNCH=true
MAILING_LIST_ENABLED=false

SES_REGION=eu-north-1
SES_ACCESS_KEY_ID=AKIA...
SES_SECRET_ACCESS_KEY=...

MATOMO_URL=https://analytics.owenrees.eu/
MATOMO_SITE_ID=6

TABLEBASE_PATH=/opt/chesstrainer/tablebases

# Optional:
# RELEASE_COOKIE=...
```

The production endpoint binds to `127.0.0.1` only. Caddy is the public
entry point.

## Matomo analytics

Set `MATOMO_URL` and `MATOMO_SITE_ID` to enable cookieless analytics on public
pages and the guest trainer. Signed-in account and admin pages are excluded.

The privacy controls, Matomo server settings, retention, and opt-out behaviour
are documented in `docs/analytics.md`.

Generate the two secrets:

```sh
openssl rand -base64 64   # SECRET_KEY_BASE
openssl rand -hex 32      # Postgres password
```

### Secret key base

`SECRET_KEY_BASE` is required in production; the release raises at boot without
it. It signs cookies, session tokens, LiveView tokens, and mailing-list
confirmation links.

Generate it with `mix phx.gen.secret` or:

```sh
openssl rand -base64 64
```

Keep it stable. Rotating it signs every user out and invalidates outstanding
confirmation and unsubscribe links. Never reuse the dev/test value or commit it.

Verify it is set without printing it:

```sh
sudo awk -F= '/^SECRET_KEY_BASE=/{print length($2)}' /etc/chesstrainer/env
```

## Postgres env file

`/etc/chesstrainer/postgres.env`:

```sh
POSTGRES_USER=chesstrainer
POSTGRES_PASSWORD=...
POSTGRES_DB=chesstrainer_prod
```

Postgres 18 stores data under `/var/lib/postgresql/18/docker`, so the
Compose volume mounts the parent:

```yaml
volumes:
  - chesstrainer_pgdata:/var/lib/postgresql
```

## Local tablebases (optional)

The production tablebase directory is `/opt/chesstrainer/tablebases`. Keep the
`.rtbw`/`.rtbz` files flat in that directory, and make sure the `chesstrainer`
user can read them:

```sh
sudo install -d -o chesstrainer -g chesstrainer /opt/chesstrainer/tablebases
sudo chown -R chesstrainer:chesstrainer /opt/chesstrainer/tablebases
sudo chmod -R u=rwX,g=rX,o= /opt/chesstrainer/tablebases
```

Set the path in `/etc/chesstrainer/env`:

```sh
TABLEBASE_PATH=/opt/chesstrainer/tablebases
```

Then restart the service, because `TABLEBASE_PATH` is read at boot:

```sh
sudo systemctl restart chesstrainer
```

Check `/health`. It should move from `degraded` / `not_configured` to
`ok` / `local`:

```sh
curl -s http://127.0.0.1:4100/health
sudo journalctl -u chesstrainer -n 50 --no-pager | grep -i tablebase
```

If the path is missing, unreadable, or empty, the app falls back to Lichess and
health stays `degraded` but still returns 200.

To refresh the files:

```sh
mix tablebase.fetch --path /opt/chesstrainer/tablebases
sudo chown -R chesstrainer:chesstrainer /opt/chesstrainer/tablebases
sudo systemctl restart chesstrainer
```

## First-time setup

Run as root or with sudo:

```sh
useradd --system --user-group \
  --home-dir /opt/chesstrainer \
  --create-home \
  --shell /usr/sbin/nologin \
  chesstrainer

install -d -o chesstrainer -g chesstrainer /opt/chesstrainer/releases
install -d -o chesstrainer -g chesstrainer /opt/chesstrainer/src

install -d -m 755 /etc/chesstrainer
install -m 600 /dev/null /etc/chesstrainer/env
install -m 600 /dev/null /etc/chesstrainer/postgres.env
chown root:root /etc/chesstrainer/env /etc/chesstrainer/postgres.env
```

Edit both files with `sudoedit` and set the generated secrets and
`DATABASE_URL`.

## Unified Compose: add Postgres

Add the `chesstrainer-db` service and `chesstrainer_pgdata` volume from
`deploy/postgres.compose.yml` to the VPS's existing unified
`docker-compose.yml`. Do not run the reference file as a separate project.

The image is pinned directly in the unified compose:

```yaml
image: postgres:18.6
```

For an immutable pin, replace it with the exact digest:

```yaml
image: postgres:18.6@sha256:...
```

There is no `POSTGRES_IMAGE` environment variable involved.

Because `postgres.env` is root-owned `0600`, run Compose with `sudo`:

```sh
sudo docker compose -f <UNIFIED_COMPOSE> config >/dev/null
sudo docker compose -f <UNIFIED_COMPOSE> up -d chesstrainer-db
sudo docker compose -f <UNIFIED_COMPOSE> ps chesstrainer-db
sudo docker compose -f <UNIFIED_COMPOSE> logs --tail=50 chesstrainer-db
```

Verify the database:

```sh
sudo docker compose -f <UNIFIED_COMPOSE> exec -T chesstrainer-db \
  psql -U chesstrainer -d chesstrainer_prod -c 'select 1;'
```

To change the Postgres version:

```sh
# edit the image: line in the unified compose
sudo docker compose -f <UNIFIED_COMPOSE> pull chesstrainer-db
sudo docker compose -f <UNIFIED_COMPOSE> up -d chesstrainer-db
```

## systemd unit

From the deploy artifact copy:

```sh
sudo install -o root -g root -m 644 /opt/chesstrainer/src/deploy/chesstrainer.service \
  /etc/systemd/system/chesstrainer.service
sudo systemctl daemon-reload
sudo systemctl enable chesstrainer
```

The unit includes `ConditionPathExists=/opt/chesstrainer/current/bin/server`, so
it is safe to enable before the first release. systemd skips it until a release
is in place.

## Caddy

On the current VPS the Caddyfile is a single file with no imports. Add the block
from `deploy/Caddyfile` by hand:

```caddy
innersquare.app {
    encode zstd gzip
    reverse_proxy 127.0.0.1:4100
}

www.innersquare.app {
    redir https://innersquare.app{uri} permanent
}
```

If a new VPS uses imports, put the block in its own site file instead.

Do **not** switch Caddy until a release is running and verified on
`127.0.0.1:4100`. Before that, keep the static coming-soon site live.

Validate and reload:

```sh
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Do not let a deploy overwrite the shared Caddyfile.

## Building a release

Build on a machine matching Ubuntu 24.04 / glibc 2.39, or let CI do it.
The release tarball is the contents of the release directory:

```sh
npm ci --prefix assets --no-audit --no-fund

export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release

tar -czf chesstrainer-release.tar.gz -C _build/prod/rel/chesstrainer .
```

`npm ci` is required before `mix assets.deploy`: Tailwind imports the
Chessground CSS and esbuild bundles the package from `assets/node_modules`.

`mix assets.deploy` runs `compile` first so the generated LiveView colocated
CSS exists.

## First deploy and Caddy switch

Upload the tarball:

```sh
scp chesstrainer-release.tar.gz <VPS_USER>@<VPS_HOST>:/tmp/
```

On the VPS:

```sh
sudo /opt/chesstrainer/src/deploy/activate /tmp/chesstrainer-release.tar.gz
```

The script:

1. Extracts into `/opt/chesstrainer/releases/<timestamp>`
2. Fixes ownership
3. Flips `/opt/chesstrainer/current`
4. Restarts `chesstrainer.service`
5. Migrations run via `ExecStartPre`
6. Polls `/health`
7. Rolls back to the previous release on failure
8. Prunes old releases, keeping 5 by default

Verify locally before touching Caddy:

```sh
curl -i http://127.0.0.1:4100/health
curl -i http://127.0.0.1:4100/
sudo journalctl -u chesstrainer -n 100 --no-pager
```

Then add the Caddy block and reload. Verify publicly:

```sh
curl -I https://innersquare.app/
curl -I https://innersquare.app/privacy
curl -I https://innersquare.app/terms-conditions
```

## Subsequent deploys

```sh
scp chesstrainer-release.tar.gz <VPS_USER>@<VPS_HOST>:/tmp/
ssh <VPS_USER>@<VPS_HOST>
sudo /opt/chesstrainer/src/deploy/activate /tmp/chesstrainer-release.tar.gz
```

Optional overrides:

```sh
RELEASE_ID=20261109120000 \
HEALTH_URL=http://127.0.0.1:4100/health \
KEEP_RELEASES=5 \
sudo -E /opt/chesstrainer/src/deploy/activate /tmp/chesstrainer-release.tar.gz
```

## GitHub Actions CD

Merging to `main` (or running the workflow manually) tests, builds, uploads,
and deploys the release. The deploy job uses SSH as `owen`.

### Deploy key

Generate a dedicated key, not your personal one:

```sh
ssh-keygen -t ed25519 -C "github-actions-chesstrainer" \
  -f ~/.ssh/chesstrainer_deploy -N ""
ssh-copy-id -i ~/.ssh/chesstrainer_deploy.pub owen@<VPS_HOST>
```

`VPS_HOST` must be the public IP or DNS name reachable from GitHub. Do not use
a local SSH alias such as `personal-projects`.

### Passwordless sudo for the deploy scripts

```sh
sudo visudo -f /etc/sudoers.d/chesstrainer-deploy
```

```text
owen ALL=(root) NOPASSWD: /opt/chesstrainer/src/deploy/activate, /opt/chesstrainer/src/deploy/rollback
```

Validate:

```sh
sudo chown root:root /etc/sudoers.d/chesstrainer-deploy
sudo chmod 0440 /etc/sudoers.d/chesstrainer-deploy
sudo visudo -c
sudo -n -l /opt/chesstrainer/src/deploy/activate
sudo -n -l /opt/chesstrainer/src/deploy/rollback
```

### GitHub environment

Create the **production** environment, optionally with required reviewers, and
add environment secrets:

| Secret | Value |
|---|---|
| `VPS_HOST` | public VPS IP or DNS name |
| `VPS_USER` | `owen` |
| `VPS_SSH_KEY` | private deploy key |
| `VPS_KNOWN_HOSTS` | `ssh-keyscan -H <VPS_HOST>` output |

Generate known_hosts with:

```sh
ssh-keyscan -H <VPS_HOST>
```

### Workflow

The workflow:

1. Runs `mix precommit` against Postgres.
2. Builds the release artifact on `ubuntu-24.04`.
3. On `main` or `workflow_dispatch`, uploads the tarball, installs the SSH key,
   runs `sudo -n .../activate`, and performs public smoke checks.
4. A failed activation health check rolls back to the previous release.

Manual dispatch is available from the Actions UI or:

```sh
gh workflow run ci.yml --ref main
```

## Rollback

```sh
sudo /opt/chesstrainer/src/deploy/rollback
```

Or target a specific release:

```sh
sudo /opt/chesstrainer/src/deploy/rollback 20261109120000
```

The script flips `current`, restarts the service, and checks `/health`.

## Logs and health

```sh
sudo systemctl status chesstrainer
sudo journalctl -u chesstrainer -n 100 --no-pager
curl -i http://127.0.0.1:4100/health
```

`/health` returns JSON with `status`, `db`, `tablebase`, and `process`.
It returns 200 for `ok`/`degraded` and 503 for `down`. A missing local tablebase
reports `degraded` but still 200 because Lichess fallback is available.

## Backups

Take a logical backup of the production database:

```sh
sudo docker compose -f <UNIFIED_COMPOSE> \
  exec -T chesstrainer-db pg_dump -U chesstrainer chesstrainer_prod \
  | gzip > /var/backups/chesstrainer-$(date -u +%Y%m%d%H%M%S).sql.gz
```

Example nightly entry in root's crontab (`sudo crontab -e`):

```cron
15 3 * * * docker compose -f /home/owen/docker-compose.yml exec -T chesstrainer-db pg_dump -U chesstrainer chesstrainer_prod | gzip > /var/backups/chesstrainer-$(date +\%Y\%m\%d).sql.gz
```

Keep `/var/backups` outside `/opt/chesstrainer/releases` and copy backups off
the VPS regularly.

## New VPS checklist

1. Ubuntu 24.04, DNS pointed at the VPS, firewall allows 22/80/443.
2. Docker, Compose, Caddy, and runtime libraries installed.
3. `chesstrainer` user, `/opt/chesstrainer` layout, root-owned env files.
4. `chesstrainer-db` merged into the unified compose and healthy.
5. systemd unit installed and enabled; `ConditionPathExists` keeps it skipped
   until a release exists.
6. Release built on a matching Ubuntu runner and activated.
7. `/health` and `/` verified on `127.0.0.1:4100`.
8. Caddy block added, validated, reloaded.
9. Public `/`, `/privacy`, `/terms-conditions`, and `/health` verified.
10. Backups scheduled and tested.
