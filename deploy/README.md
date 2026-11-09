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
| Postgres | `postgres:18.6`, pinned directly in the unified compose |
| Caddy | 2.11.9 |
| Docker | 29.9.3 |
| Docker Compose | v5.7.0 |

The release ships its own ERTS. The host needs the runtime libraries for the
Rust NIF (`libstdc++6`), OpenSSL, and CA certificates.

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
└── current -> releases/20261109153000
```

`/etc/chesstrainer/env` is the application environment file, owned by
`root:root` with mode `0600`.

`/etc/chesstrainer/postgres.env` holds the Postgres container credentials,
also `root:root` and `0600`.

The app runs as the dedicated `chesstrainer` system user. It must own
`/opt/chesstrainer` so it can write `priv/static/backups`.

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

MATOMO_URL=https://analytics.innersquare.app/
MATOMO_SITE_ID=1

# Optional:
# TABLEBASE_PATH=/path/to/syzygy
# RELEASE_COOKIE=...
```

The production endpoint binds to `127.0.0.1` only. Caddy is the public
entry point.

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
  - pgdata:/var/lib/postgresql
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

Add the `chesstrainer-db` service and `chesstrainer_pgdata` volume from
`deploy/postgres.compose.yml` to the VPS's existing unified
`docker-compose.yml`. Do not run the reference file as a separate project.

```sh
docker compose -f <UNIFIED_COMPOSE> up -d chesstrainer-db
docker compose -f <UNIFIED_COMPOSE> ps chesstrainer-db
```

The Postgres image is pinned directly in the unified compose:

```yaml
image: postgres:18.0
```

For an immutable pin, replace it with the exact digest:

```yaml
image: postgres:18.0@sha256:...
```

There is no `POSTGRES_IMAGE` environment variable involved. To change the
Postgres version, edit the `image:` line in the unified compose, then:

```sh
docker compose -f <UNIFIED_COMPOSE> pull chesstrainer-db
docker compose -f <UNIFIED_COMPOSE> up -d chesstrainer-db
```

Install the systemd unit:

```sh
install -o root -g root -m 644 deploy/chesstrainer.service /etc/systemd/system/chesstrainer.service
systemctl daemon-reload
systemctl enable chesstrainer
```

Do not start the service until a release is in `/opt/chesstrainer/current`.

## Caddy

This VPS uses a single `/etc/caddy/Caddyfile` with no imports. Add the block
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

Validate and reload:

```sh
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
```

Do not let a deploy overwrite the shared Caddyfile.

## Building a release

Build on a machine matching Ubuntu 24.04 / glibc 2.39, or let CI do it.
The release tarball is the contents of the release directory:

```sh
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release

tar -czf chesstrainer-release.tar.gz -C _build/prod/rel/chesstrainer .
```

`mix assets.deploy` runs `compile` first so the generated LiveView colocated
CSS exists.

## Deploying a release

Copy the tarball to the VPS, then:

```sh
sudo deploy/activate /tmp/chesstrainer-release.tar.gz
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

Optional overrides:

```sh
RELEASE_ID=20261109120000 \
HEALTH_URL=http://127.0.0.1:4100/health \
KEEP_RELEASES=5 \
sudo -E deploy/activate /tmp/chesstrainer-release.tar.gz
```

## Rollback

```sh
sudo deploy/rollback
```

Or target a specific release:

```sh
sudo deploy/rollback 20261109120000
```

The script flips `current`, restarts the service, and checks `/health`.

## Logs and health

```sh
systemctl status chesstrainer
journalctl -u chesstrainer -n 100 --no-pager
curl -i http://127.0.0.1:4100/health
```

## Backups

Take a logical backup of the production database:

```sh
docker compose -f <UNIFIED_COMPOSE> \
  exec -T chesstrainer-db pg_dump -U chesstrainer chesstrainer_prod \
  | gzip > /var/backups/chesstrainer-$(date -u +%Y%m%d%H%M%S).sql.gz
```

Keep the backup directory outside `/opt/chesstrainer/releases`.
