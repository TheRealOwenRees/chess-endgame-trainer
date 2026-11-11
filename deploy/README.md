# Production deployment

Phoenix release on the shared Ubuntu VPS, behind Caddy, with Postgres in Docker.

```text
Internet
  └─ Cloudflare (TLS, WAF, edge rate limiting)
       └─ Caddy :443 (cloudflare ranges only)
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

Database dumps live in `/var/backups/chesstrainer`, outside `/opt/chesstrainer`
and `priv/static`. See §Backups.

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

## Read-only database access

The app connects as `chesstrainer`, which is a superuser. Use a separate
read-only role for inspection, debugging, and dashboards.

Create it once per environment:

```sh
sudo docker compose -f <UNIFIED_COMPOSE> exec -T chesstrainer-db \
  psql -U chesstrainer -d chesstrainer_prod <<'SQL'
CREATE ROLE chesstrainer_ro LOGIN PASSWORD '<generated-password>';
GRANT CONNECT ON DATABASE chesstrainer_prod TO chesstrainer_ro;
GRANT USAGE ON SCHEMA public TO chesstrainer_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO chesstrainer_ro;

-- Cover tables created by future migrations. Migrations run as chesstrainer.
ALTER DEFAULT PRIVILEGES FOR ROLE chesstrainer IN SCHEMA public
  GRANT SELECT ON TABLES TO chesstrainer_ro;

-- Optional: read other sessions and server settings in pg_stat_* views.
GRANT pg_read_all_stats TO chesstrainer_ro;
SQL
```

Generate the password with `openssl rand -hex 32` and keep it in a password
manager. The only access it has is `SELECT`; there are no `INSERT`, `UPDATE`,
`DELETE`, or object-creation grants. If the role already exists, skip the
`CREATE ROLE` line and re-run the grants.

Optional defence in depth:

```sql
ALTER ROLE chesstrainer_ro SET default_transaction_read_only = on;
```

This is not a hard boundary (the role can override it per session), but it
turns an accidental write into an error.

### Connect from the VPS

`docker exec` connects over the container's Unix socket, which the Postgres
image trusts locally, so no password is needed:

```sh
sudo docker exec -it chesstrainer-db \
  psql -U chesstrainer_ro -d chesstrainer_prod
```

### Connect from a workstation over SSH

Postgres is published on `127.0.0.1:5432` only. OpenSSH also disables
forwarding by default in `/etc/ssh/sshd_config` (`AllowTcpForwarding no`).
Allow local forwarding for the deploy user only, restricted to Postgres, by
appending this to the **end** of that file:

```text
Match User <username>
    AllowTcpForwarding local
    PermitOpen 127.0.0.1:5432
```

Then validate and reload:

```sh
sudo sshd -t
sudo systemctl reload ssh
sudo sshd -T -C user=<username>,host=localhost,addr=127.0.0.1 | grep -iE 'allowtcpforwarding|permitopen'
```

Open the tunnel (local port `5433` because the dev database already binds
`5432`):

```sh
ssh -N -L 5433:127.0.0.1:5432 <VPS_USER>@<VPS_HOST>
```

Connect from a second terminal:

```sh
psql "postgres://chesstrainer_ro@127.0.0.1:5433/chesstrainer_prod"
```

Install `postgresql-client` if `psql` is not available on the workstation.

To avoid the password prompt, add this to `~/.pgpass` (mode `0600`):

```text
127.0.0.1:5433:chesstrainer_prod:chesstrainer_ro:<password>
```

DBeaver uses the same tunnel. Create a PostgreSQL connection with host
`127.0.0.1`, port `5432`, database `chesstrainer_prod`, user
`chesstrainer_ro`, then on the **SSH** tab enable the tunnel with host
`<VPS_HOST>`, port `22`, user `<VPS_USER>`, and a public key. The
`AllowTcpForwarding local` rule above is required for any tunnelled client.

Reset the role password:

```sh
sudo docker compose -f <UNIFIED_COMPOSE> exec -T chesstrainer-db \
  psql -U chesstrainer -d chesstrainer_prod \
  -c "ALTER ROLE chesstrainer_ro PASSWORD '<new-password>';"
```

Verify the role is read-only:

```sh
psql "postgres://chesstrainer_ro@127.0.0.1:5433/chesstrainer_prod" \
  -c 'select current_user, current_database();'
psql "postgres://chesstrainer_ro@127.0.0.1:5433/chesstrainer_prod" \
  -c 'create table should_fail (i int);'
```

The second command must fail with `permission denied for schema public`.

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

The backup unit and timer are installed separately; see §Backups.

## Caddy

Add the site block from `deploy/Caddyfile` by hand. It imports
`cloudflare-ranges.caddy`, which is generated by
`deploy/update-cloudflare-ranges.sh` and refreshed by a systemd timer.

Caddy must only accept Cloudflare traffic and must replace `X-Forwarded-For`
with Cloudflare's `CF-Connecting-IP` value:

```caddy
innersquare.app {
    encode zstd gzip

    @cloudflare {
        import cloudflare-ranges.caddy
    }

    handle @cloudflare {
        reverse_proxy 127.0.0.1:4100 {
            header_up X-Forwarded-For {http.request.header.CF-Connecting-IP}
        }
    }

    handle {
        respond "Access Denied" 403
    }
}

www.innersquare.app {
    redir https://innersquare.app{uri} permanent
}
```

Install the range file and the hourly refresh timer:

```sh
sudo install -m 0755 /opt/chesstrainer/src/deploy/update-cloudflare-ranges.sh \
  /usr/local/sbin/chesstrainer-update-cloudflare-ranges
sudo install -m 0644 /opt/chesstrainer/src/deploy/cloudflare-ranges.caddy \
  /etc/caddy/cloudflare-ranges.caddy
sudo install -m 0644 /opt/chesstrainer/src/deploy/chesstrainer-cloudflare-ranges.service \
  /etc/systemd/system/chesstrainer-cloudflare-ranges.service
sudo install -m 0644 /opt/chesstrainer/src/deploy/chesstrainer-cloudflare-ranges.timer \
  /etc/systemd/system/chesstrainer-cloudflare-ranges.timer
```

The installed pieces are:

| Path | Mode | Purpose |
|---|---|---|
| `/usr/local/sbin/chesstrainer-update-cloudflare-ranges` | `0755` | fetch/validate/reload script |
| `/etc/caddy/cloudflare-ranges.caddy` | `0644` | generated `remote_ip` list |
| `/etc/systemd/system/chesstrainer-cloudflare-ranges.service` | `0644` | oneshot service |
| `/etc/systemd/system/chesstrainer-cloudflare-ranges.timer` | `0644` | hourly timer |

If `/opt/chesstrainer/src/deploy` is not present on the VPS, create the same
four files directly with `sudo tee` from the canonical contents in `deploy/`.
The timer only depends on the installed copies; it does not read the repo.

Run it once manually and enable the timer:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now chesstrainer-cloudflare-ranges.timer
sudo systemctl start chesstrainer-cloudflare-ranges.service
sudo journalctl -u chesstrainer-cloudflare-ranges.service -n 50 --no-pager
```

The script fetches <https://www.cloudflare.com/ips-v4> and
<https://www.cloudflare.com/ips-v6>, validates the result, and reloads Caddy
only when the ranges actually changed. If the download, Caddy validation or
reload fails, it keeps or restores the previous file.

Check the timer and last run:

```sh
systemctl list-timers chesstrainer-cloudflare-ranges.timer
systemctl status chesstrainer-cloudflare-ranges.service
journalctl -u chesstrainer-cloudflare-ranges.service --since "24 hours ago"
```

Do not edit `/etc/caddy/cloudflare-ranges.caddy` by hand; the next timer run
overwrites it.

To update the refresher itself, replace the installed script or unit files from
the deploy directory, then:

```sh
sudo systemctl daemon-reload
sudo systemctl restart chesstrainer-cloudflare-ranges.timer
sudo systemctl start chesstrainer-cloudflare-ranges.service
```

Without this, `TRUST_FORWARDED_FOR=true` records a Cloudflare edge address
instead of the visitor, and the login throttle and guest puzzle limit bucket
whole Cloudflare POPs together.

If a new VPS uses imports, put the site block in its own file instead; keep the
`import cloudflare-ranges.caddy` path next to the Caddyfile.

Do **not** switch Caddy until a release is running and verified on
`127.0.0.1:4100`. Before that, keep the static coming-soon site live.

Validate and reload:

```sh
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

A direct request to the origin with a forged `CF-Connecting-IP` header should
receive `403 Access Denied`.

Do not let a deploy overwrite the shared Caddyfile.

See `docs/security.md` for the application throttle, real-IP setup and the
Cloudflare edge controls. Production currently has Bot Fight Mode enabled and
the free-plan login flood rule: 10 POSTs per 10 seconds per IP, blocked for 10
seconds.

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
3. Takes a verified pre-deploy database dump, aborting if it fails (see §Backups)
4. Flips `/opt/chesstrainer/current`
5. Restarts `chesstrainer.service`
6. Migrations run via `ExecStartPre`
7. Polls `/health`
8. Rolls back to the previous release on failure
9. Prunes old releases, keeping 5 by default

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

Every activation takes a verified pre-deploy dump before migrations run. If
Postgres is intentionally unavailable and you accept the risk, add
`SKIP_PRE_DEPLOY_BACKUP=1` to the override list; see §Backups.

## GitHub Actions CD

Merging to `main` (or running the workflow manually) tests, builds, uploads,
and deploys the release. The deploy job uses SSH as `<username>`.

### Deploy key

Generate a dedicated key, not your personal one:

```sh
ssh-keygen -t ed25519 -C "github-actions-chesstrainer" \
  -f ~/.ssh/chesstrainer_deploy -N ""
ssh-copy-id -i ~/.ssh/chesstrainer_deploy.pub <username>@<VPS_HOST>
```

`VPS_HOST` must be the public IP or DNS name reachable from GitHub. Do not use
a local SSH alias such as `personal-projects`.

### Passwordless sudo for the deploy scripts

```sh
sudo visudo -f /etc/sudoers.d/chesstrainer-deploy
```

```text
<username> ALL=(root) NOPASSWD: /opt/chesstrainer/src/deploy/activate, /opt/chesstrainer/src/deploy/rollback
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
| `VPS_USER` | `<username>` |
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
   runs `sudo -n .../activate`, and performs public smoke checks. Activation
   takes a pre-deploy dump first and fails if it cannot.
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

Rollback reverts the release, not the database: migrations are not reversed. If
a migration changed data, restore the matching pre-deploy dump instead; see
§Backups.

## Logs and health

```sh
sudo systemctl status chesstrainer
sudo journalctl -u chesstrainer -n 100 --no-pager
curl -i http://127.0.0.1:4100/health
```

`/health` returns JSON with `status`, `db`, `tablebase`, and `process`.
It returns 200 for `ok`/`degraded` and 503 for `down`. A missing local tablebase
reports `degraded` but still 200 because Lichess fallback is available.

### Reading production logs

Production emits one JSON object per line. Use `-o cat` so journald prints the
raw line instead of its own field wrapper, then pipe to `jq`:

```sh
# Recent logs, pretty-printed
sudo journalctl -u chesstrainer -o cat -n 50 --no-pager | jq .

# Errors only
sudo journalctl -u chesstrainer -o cat --since "1 hour ago" | jq 'select(.level == "error")'

# Everything from one request
sudo journalctl -u chesstrainer -o cat | jq 'select(.request_id == "REQUEST_ID")'

# Crash reasons and stacktraces
sudo journalctl -u chesstrainer -o cat | jq -r 'select(.error) | .error.reason, (.error.stacktrace[]?)'
```

Each line has `timestamp`, `level` and `message`, plus `request_id` when one
exists. Access lines add `method`, `path`, `status` and `duration_ms`; crashes
add an `error` object with `kind`, `reason` and `stacktrace`. Query parameters
and request bodies are never logged, token-shaped path segments are redacted,
and email addresses or credentials in metadata render as `[REDACTED]`.

The full field table, redaction rules and examples for adding background logs
are in [`docs/logging.md`](../docs/logging.md).

Dev and test still use the readable `[level] message` formatter.

### Keep the journal

By default some distributions keep journald logs in memory only. On the VPS,
make sure they survive a reboot and have a retention budget:

```sh
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
journalctl --disk-usage
```

Set `Storage=persistent` and a `SystemMaxUse=` value in
`/etc/systemd/journald.conf` if the distribution does not already. journald
rate-limits bursts; if a crash storm drops lines, raise `RateLimitBurst` or
`RateLimitIntervalSec` there.

## Interactive shell and user management

Attach an IEx shell to the **running** release. This does not restart the
service and does not require direct database access:

```sh
sudo /opt/chesstrainer/current/bin/chesstrainer remote
```

You should get a prompt like `iex(chesstrainer@<host>)1>`. Exit with **Ctrl-C
twice**. Never call `System.halt/0`, `:init.stop/0`, or
`Application.stop(:chesstrainer)` from this shell — those stop production.

Use it for account and role management. Go through the application contexts
(not SQL) so changesets, bcrypt hashing, timestamps, and token bookkeeping stay
consistent:

```elixir
# Look up by email or username
u = Chesstrainer.Accounts.get_user_by_login("owen")

# Promote or demote
{:ok, u} = Chesstrainer.Accounts.update_user_role(u, :super_admin)

# Confirm an account without sending email
{:ok, u} = Chesstrainer.Repo.update(Chesstrainer.Accounts.User.confirm_changeset(u))

# Create an account, generating its password server-side
pw = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)

{:ok, u} =
  Chesstrainer.Accounts.register_user(%{
    email: "you@example.com",
    username: "owen",
    password: pw
  })

{:ok, u} = Chesstrainer.Repo.update(Chesstrainer.Accounts.User.confirm_changeset(u))
pw
```

Notes:

- `register_user/1` hashes the password with bcrypt; `password` is virtual and
  is never written to the database.
- Do not type passwords into the shell if you can avoid it — IEx may keep a
  history file — and never paste a password from shell history. Generate one as
  above and change it later at `/users/profile/settings`.
- `mix accounts.promote` still works when a compiled source checkout is present
  on the host, but the release shell is the supported production path.
- There is no guard against demoting the last `super_admin` outside the future
  admin UI, so check the result before demoting.

If `remote` fails while booting its client VM (for example
`Kernel pid terminated (logger)` with `code_server`/`persistent_term` in the
trace), the deployed release is stale, mixed, or missing IEx: rebuild and
redeploy it. To attach in the meantime, use the release's own ERTS:

```sh
sudo bash -c '
  COOKIE=$(cat /opt/chesstrainer/current/releases/COOKIE)
  exec /opt/chesstrainer/current/erts-*/bin/erl \
    -sname debug -setcookie "$COOKIE" -remsh chesstrainer
'
```

That shell speaks Erlang syntax, so quote Elixir module atoms, e.g.
`'Elixir.Chesstrainer.Accounts':register_user(...)`.

## Backups

Backups are produced on the VPS, encrypted there, and pulled to a workstation.
Nothing leaves the VPS unencrypted, and the VPS never holds the key that could
read the archives.

### What runs

| Where | What | When | Retention |
|---|---|---|---|
| VPS | `chesstrainer-backup.timer` → `chesstrainer-backup.service` | daily 03:15 UTC, `Persistent=true`, 5 min jitter | 3 days plaintext, 14 days encrypted |
| VPS | the same script, called by `deploy/activate` | before every migration | last 5 pre-deploy sets |
| Workstation | `chesstrainer-backup-pull.timer` | daily 12:00 local, 10 min after boot | 7 daily, 4 weekly, 6 monthly |
| Workstation | `chesstrainer-backup-drill.timer` | monthly on the 1st at 09:00 | `drills.log` is never pruned |

Each run writes one JSON line (`backup.completed`, `backup.failed`,
`backup.skipped`, `pull.completed`, `pull.failed`, `pull.skipped`,
`drill.completed`, `drill.failed`) so #140's log shipping can alert on it. A
`skipped` line means another run held the lock; it is not an alarm.

### What a dump contains

- `<ts>.dump` — `pg_dump -Fc` of `chesstrainer_prod`
- `<ts>.globals.sql` — `pg_dumpall --globals-only`, enough to recreate
  `chesstrainer` and `chesstrainer_ro` on a fresh cluster
- `<ts>.counts` — row counts for `users`, `endgames`, `attempts`, used by the drill
- `<ts>.sha256` — checksums for the three files above

Not backed up, by design: tablebases and the tablebase cache (both are
re-fetchable), anything under `priv/static`, and release tarballs. Dumps contain
user emails and bcrypt hashes: they are `0600 root` while plaintext, encrypted
before they leave the box, and pruned aggressively.

### RPO and RTO

RPO is 24 hours on the VPS and "the age of the newest pulled archive" off-box.
The pull runs daily, so a laptop that is off for a day leaves the newest
off-site copy around 48 hours old; the VPS keeps 14 days of encrypted archives,
which bounds how far behind the pull can fall. RTO is under an hour: create the
database, restore the newest dump, activate a release (see *Disaster recovery*).

### One-time setup: VPS

Install `age`. Encryption happens on the server; only the workstation can
decrypt.

```sh
sudo apt install age
```

Create the configuration file. Generate `AGE_RECIPIENT` on the workstation
first (next section) and paste the public key.

```sh
sudo install -m 600 /dev/null /etc/chesstrainer/backup.env
sudoedit /etc/chesstrainer/backup.env
```

Start from `deploy/backup.env.example`. The required values are `AGE_RECIPIENT`
and `HEALTHCHECK_URL`.

Create a healthchecks.io check with a period of 1 day and a grace time of 4
hours, then paste its ping URL into `HEALTHCHECK_URL`. The script pings it after
a good run and `<url>/fail` after a bad one, so silence means "no backup
finished", even when the VPS itself is down.

Install the script and units:

```sh
sudo install -m 0755 /opt/chesstrainer/src/deploy/backup \
  /usr/local/sbin/chesstrainer-backup
sudo install -m 0644 \
  /opt/chesstrainer/src/deploy/chesstrainer-backup.service \
  /opt/chesstrainer/src/deploy/chesstrainer-backup.timer \
  /opt/chesstrainer/src/deploy/chesstrainer-backup-failure.service \
  /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now chesstrainer-backup.timer
```

The timer runs the installed `/usr/local/sbin/chesstrainer-backup`, not the
copy under `/opt/chesstrainer/src`, because that tree is writable by the
application user. When `deploy/backup` changes, copy it to both places so the
timer and `deploy/activate` use the same script.

Run it once and inspect the result:

```sh
sudo systemctl start chesstrainer-backup
sudo journalctl -u chesstrainer-backup -n 20 --no-pager -o cat
sudo ls -l /var/backups/chesstrainer /var/backups/chesstrainer/offsite
systemctl list-timers chesstrainer-backup.timer
```

Expect a `.dump`, `.globals.sql`, `.counts` and `.sha256` at mode `0600`, and
one `.tar.age` in `offsite/` at mode `0644`. `offsite/` is the only thing the
workstation reads, which is why the pull needs no `sudo`. The vault directory is
`0711`, so the workstation user can traverse into `offsite/` but cannot list the
plaintext dumps.

### One-time setup: workstation

```sh
sudo apt install age rsync
mkdir -p ~/.config/chesstrainer
chmod 700 ~/.config/chesstrainer
age-keygen -o ~/.config/chesstrainer/age.key
chmod 600 ~/.config/chesstrainer/age.key
grep 'public key' ~/.config/chesstrainer/age.key
```

Copy that public key into `AGE_RECIPIENT` on the VPS. **Back up the private
key** (password manager, printed copy, offline disk): without it every archive
is unreadable, and the VPS deliberately cannot decrypt them.

Create the pull configuration:

```sh
install -m 600 /dev/null ~/.config/chesstrainer/backup-pull.env
$EDITOR ~/.config/chesstrainer/backup-pull.env
```

Start from `deploy/workstation/backup-pull.env.example`. `DEST` should point at
a real disk, for example `/mnt/Mint Data/chesstrainer-backups`. The script
refuses to run when `DEST`'s parent is missing, so an unmounted disk cannot
silently fill the root filesystem.

Set `PULL_HEALTHCHECK_URL` to a second healthchecks.io check with a long period
(for example 72 hours) if you want to hear about it when the workstation stops
pulling. Leave it empty for journal-only reporting.

Install the scripts and user units:

```sh
REPO=~/Desktop/chess-trainer   # wherever this repo is cloned

install -d ~/.local/bin
install -m 0755 "$REPO/deploy/workstation/backup-pull" ~/.local/bin/chesstrainer-backup-pull
install -m 0755 "$REPO/deploy/workstation/backup-drill" ~/.local/bin/chesstrainer-backup-drill

install -d ~/.config/systemd/user
install -m 0644 \
  "$REPO/deploy/workstation/chesstrainer-backup-pull.service" \
  "$REPO/deploy/workstation/chesstrainer-backup-pull.timer" \
  "$REPO/deploy/workstation/chesstrainer-backup-drill.service" \
  "$REPO/deploy/workstation/chesstrainer-backup-drill.timer" \
  "$REPO/deploy/workstation/chesstrainer-backup-alert@.service" \
  ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now chesstrainer-backup-pull.timer
systemctl --user enable --now chesstrainer-backup-drill.timer
sudo loginctl enable-linger "$USER"
```

`enable-linger` lets the user timers run while the laptop is on but you are not
logged in. The pull also fires ten minutes after boot, and `Persistent=true`
catches up after the machine was off. Verify lingering stuck:

```sh
loginctl show-user "$USER" -p Linger    # Linger=yes
```

Run the first pull and drill by hand:

```sh
~/.local/bin/chesstrainer-backup-pull
ls -l "/mnt/Mint Data/chesstrainer-backups"
~/.local/bin/chesstrainer-backup-drill
cat "/mnt/Mint Data/chesstrainer-backups/drills.log"
```

A passing drill line looks like:

```json
{"timestamp":"2026-11-11T21:05:46Z","event":"drill.completed","archive":"20261111T120000Z.tar.age","result":"pass","counts":"users=3,endgames=42,attempts=900","duration_s":3}
```

The drill creates a throwaway `postgres:18.6` container, applies the globals
dump, asserts that `chesstrainer` and `chesstrainer_ro` exist, restores into
`chesstrainer_restore`, and compares the three row counts with the `.counts`
file from dump time. Restored counts may be higher (the counts are taken moments
before the dump); lower counts fail the drill.

### Retention

| Location | Plaintext | Encrypted | Notes |
|---|---|---|---|
| VPS `/var/backups/chesstrainer` | 3 days | 14 days | pre-deploy sets: last 5 |
| Workstation `DEST` | never | 7 daily, 4 weekly, 6 monthly | monthly copies outlive the VPS copies |

The VPS is a staging area for the workstation; weekly and monthly generations
accumulate there. If the laptop is off for more than 14 days, the archives the
VPS dropped in the meantime are gone — that is the documented off-site RPO
trade-off. Moving to an always-on destination (a second host or object storage
with restic) is tracked in #151.

### Restore a dump

Always restore into a scratch database first. From an archive on the
workstation:

```sh
WORK=$(mktemp -d)
age --decrypt -i ~/.config/chesstrainer/age.key \
  -o "$WORK/dump.tar" \
  "/mnt/Mint Data/chesstrainer-backups/<timestamp>.tar.age"
tar -xf "$WORK/dump.tar" -C "$WORK"
(cd "$WORK" && sha256sum --check --strict <timestamp>.sha256)
```

Then restore into a scratch container:

```sh
docker run --rm -d --name restore-check \
  -e POSTGRES_PASSWORD=restore -e POSTGRES_HOST_AUTH_METHOD=trust postgres:18.6
docker exec restore-check psql -U postgres -c 'create database chesstrainer_restore'
docker exec -i restore-check pg_restore -U postgres -d chesstrainer_restore \
  --single-transaction --exit-on-error < "$WORK/<timestamp>.dump"
docker exec restore-check psql -U postgres -d chesstrainer_restore \
  -c 'select count(*) from users; select count(*) from attempts;'
docker rm -f restore-check
rm -rf "$WORK"
```

### Disaster recovery

1. Build a new VPS following this README through *First-time setup*, without
   activating a release or switching Caddy.
2. Decrypt and unpack the newest archive on the workstation (above).
3. Copy the dump and globals to the new VPS:
   `scp "$WORK/<timestamp>.dump" "$WORK/<timestamp>.globals.sql" <VPS_USER>@<VPS_HOST>:/tmp/`
4. Recreate the cluster roles. Connect as `chesstrainer`: it is the container's
   superuser (`POSTGRES_USER`), and the dump's final grants are issued
   `GRANTED BY chesstrainer`, which another role cannot replay. The line that
   recreates `chesstrainer` itself reports "already exists" and is harmless:
   `sudo docker exec -i chesstrainer-db psql -U chesstrainer < /tmp/<timestamp>.globals.sql`
5. Create the database and restore it:
   `sudo docker exec chesstrainer-db createdb -U chesstrainer chesstrainer_prod`
   `sudo docker exec -i chesstrainer-db pg_restore -U chesstrainer -d chesstrainer_prod --single-transaction --exit-on-error < /tmp/<timestamp>.dump`
6. Verify the row counts, activate a release, then restore the Caddy block.
7. Take a fresh backup (`sudo systemctl start chesstrainer-backup`) and pull so
   the new VPS is covered immediately.

`pg_dump` and `pg_restore` must come from the container's Postgres 18, not the
host.

### Pre-deploy dump

`deploy/activate` calls `chesstrainer-backup` with `BACKUP_TAG=predeploy` after
extracting the release and before flipping `current`, so the state before
`bin/migrate` runs in `ExecStartPre` is always recoverable. A failed dump aborts
the activation. The escape hatch is deliberate and should be rare:

```sh
sudo SKIP_PRE_DEPLOY_BACKUP=1 /opt/chesstrainer/src/deploy/activate /tmp/chesstrainer-release.tar.gz
```

If the installed script is missing, `activate` uses the `backup` next to it; if
neither exists it refuses to activate rather than migrate without a dump. The
GitHub Actions deploy job inherits the same behaviour.

### Run it by hand

Every timer can be triggered directly. On the VPS:

```sh
# exactly what the timer runs
sudo systemctl start chesstrainer-backup
sudo journalctl -u chesstrainer-backup -n 20 -o cat

# an ad-hoc dump with its own tag
sudo BACKUP_TAG=manual /usr/local/sbin/chesstrainer-backup

# schedule, last result and last exit
systemctl list-timers chesstrainer-backup.timer
systemctl show chesstrainer-backup.service -p Result -p ExecMainExitTimestamp
```

On the workstation:

```sh
# pull now, or through the unit (same PATH and OnFailure handling)
~/.local/bin/chesstrainer-backup-pull
systemctl --user start chesstrainer-backup-pull.service

# drill the newest archive, or a named one
~/.local/bin/chesstrainer-backup-drill
~/.local/bin/chesstrainer-backup-drill 20261111T213734Z.tar.age

# results and schedule
cat "/mnt/Mint Data/chesstrainer-backups/drills.log"
systemctl --user list-timers 'chesstrainer-backup-*'
```

A `backup.skipped` or `pull.skipped` line means another run held the lock; that
run reports the outcome. After fixing a failure, clear the unit with
`systemctl --user reset-failed chesstrainer-backup-pull.service` (or
`sudo systemctl reset-failed chesstrainer-backup.service`).

Enabling the pull timer fires it once straight away: its `OnBootSec=10m` is
measured from boot, so enabling it hours after boot triggers immediately. That
is expected and harmless.

### Monitoring

```sh
systemctl list-timers chesstrainer-backup.timer
sudo journalctl -u chesstrainer-backup --since "2 days ago" -o cat
sudo systemctl --failed
systemctl --user list-timers chesstrainer-backup-pull.timer chesstrainer-backup-drill.timer
journalctl --user -u chesstrainer-backup-pull --since "2 days ago" -o cat
```

A failed run produces both `backup.failed` (from the script) and
`backup.unit-failed` (from the `OnFailure` unit). The healthchecks.io check is
the backstop: if the VPS dies, the ping stops and you are emailed. The pull
fails when the newest archive is more than 48 hours old, which catches a stopped
VPS timer the next time the workstation pulls.

### Troubleshooting

| Symptom | Likely cause |
|---|---|
| `backup.failed: missing command: age` | `sudo apt install age` |
| `backup.failed: only N MB free` | disk full on the VPS; prune old releases or grow the disk |
| `backup.failed: pg_dump failed` | `chesstrainer-db` is down or restarting — check `docker ps` |
| `backup.failed: globals dump is missing role …` | the role was renamed; update `EXPECTED_ROLES` |
| `pull.failed: rsync … failed` | SSH key, host key, or the VPS is unreachable |
| `pull.failed: newest archive … is Nh old` | the VPS backup timer stopped; check it before touching the workstation |
| `drill.failed: pg_restore failed` | archive is corrupt; keep it for diagnosis and restore an earlier one |

Never put dumps anywhere under `priv/static` or the release directory, and never
restore over `chesstrainer_prod` while the application is running.

## New VPS checklist

1. Ubuntu 24.04, DNS pointed at the VPS, firewall allows 22/80/443.
2. Docker, Compose, Caddy, and runtime libraries installed.
3. `chesstrainer` user, `/opt/chesstrainer` layout, root-owned env files.
4. `chesstrainer-db` merged into the unified compose and healthy.
5. systemd unit installed and enabled; `ConditionPathExists` keeps it skipped
   until a release exists.
6. Release built on a matching Ubuntu runner and activated.
7. `/health` and `/` verified on `127.0.0.1:4100`.
8. Caddy block, `cloudflare-ranges.caddy`, and the CIDR refresh timer added;
   validated and reloaded.
9. Public `/`, `/privacy`, `/terms-conditions`, and `/health` verified.
10. Read-only role created and tunnel verified.
11. `age` installed, `/etc/chesstrainer/backup.env` written, backup script and
    units installed, timer enabled, and one manual run produces a dump plus a
    globals file.
12. Workstation age key and pull configuration installed, user timers and linger
    enabled, first pull verified, first drill passes.
13. Remote shell attaches and exits cleanly:
    `sudo /opt/chesstrainer/current/bin/chesstrainer remote` (Ctrl-C twice).
