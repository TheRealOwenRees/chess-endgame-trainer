# Login and edge security

The login surface is protected in layers. The application throttle is the
primary control; Cloudflare is the edge backstop for volume. There is no
origin-level fail2ban for HTTP logins, because it would require storing raw IP
addresses and would ban Cloudflare edge addresses on this deployment.

## Current production configuration

- Caddy accepts only Cloudflare's published ranges and forwards
  `CF-Connecting-IP` as `X-Forwarded-For`.
- `TRUST_FORWARDED_FOR=true`, so the app throttles by the real visitor address.
- Cloudflare Bot Fight Mode is enabled.
- The free-plan login flood rule allows 10 login POSTs per 10 seconds per IP and
  blocks for 10 seconds.

The short Cloudflare block is rate smoothing, not a credential lockout. The
application's 5-per-login and 10-per-address failures in a 15-minute window are
the real control.

## 1. Application login throttle

`ChesstrainerWeb.LoginThrottle` counts failures in two buckets:

| Bucket | Limit | Window |
|---|---|---|
| Normalised login (email or username) | 5 failures | 15 minutes |
| Client address | 10 failures | 15 minutes |

Blocked attempts are rejected before the database lookup and bcrypt, so they do
not consume password-hashing CPU. A successful login clears the login bucket
only, keeping the address bucket in place so one address cannot spray many
accounts.

The bucket keys are boot-scoped HMACs. Raw addresses and raw login identifiers
are never stored in ETS or written to the application logs. The login form
returns the same generic error for unknown accounts, bad passwords and
unconfirmed accounts.

Configured in `config/config.exs`:

```elixir
config :chesstrainer, ChesstrainerWeb.LoginThrottle,
  window_ms: :timer.minutes(15),
  max_per_login: 5,
  max_per_ip: 10,
  confirmation_cooldown_ms: :timer.minutes(15)
```

`auth.login.failed` and `auth.login.throttled` are documented in
`docs/logging.md`.

## 2. Real client IPs behind Cloudflare and Caddy

The production chain is:

```text
Internet
  └─ Cloudflare
       └─ Caddy :443
            └─ Phoenix 127.0.0.1:4100
```

Caddy ignores incoming `X-Forwarded-*` values by default and replaces them with
the immediate peer address. Behind Cloudflare that peer is a Cloudflare edge
node, so without configuration the app would throttle whole Cloudflare POPs
rather than individual visitors.

`deploy/Caddyfile` fixes this by:

1. accepting only Cloudflare's published ranges, and
2. setting `X-Forwarded-For` from Cloudflare's single-value `CF-Connecting-IP`
   header.

That keeps `TRUST_FORWARDED_FOR=true` safe: direct clients cannot reach the app
through Caddy, so they cannot forge the header.

Apply the block by hand on the shared Caddy host, then validate and reload:

```sh
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Refresh the Cloudflare ranges from:

- <https://www.cloudflare.com/ips-v4>
- <https://www.cloudflare.com/ips-v6>

Direct requests to the origin with a spoofed `CF-Connecting-IP` must receive
`403 Access Denied`; only Cloudflare's ranges should reach the Phoenix app. A
host firewall allowlist for Cloudflare on ports 80 and 443 is a useful
defence-in-depth addition.

## 3. Cloudflare edge rate limiting

This is for connection and request floods, not credential guessing. The
application already stops password attempts cheaply.

The production rule is the free-plan version:

| Setting | Value |
|---|---|
| Name | Login POST flood |
| Expression | `(http.request.method eq "POST" and http.request.uri.path in {"/admin/log-in" "/users/log-in"})` |
| Characteristic | IP |
| Period | 10 seconds |
| Requests | 10 |
| Action | Block |
| Duration | 10 seconds |

Because the free plan only offers a 10-second period and a 10-second block, this
is a burst limiter rather than a lasting ban. An attacker can retry after ten
seconds, but the application still stops that login after five failures and that
address after ten failures within fifteen minutes. A slow attacker staying under
10 requests per 10 seconds never gets to make useful guesses because of the app
throttle.

Bot Fight Mode is enabled as the plan-level bot control. If the plan later gains
longer rate-limit windows or managed WAF rules, raise the block duration and
consider a broader site-wide rule, such as 100 requests per 10 seconds per IP
with a managed challenge. Use Under Attack Mode during an active incident.

### Registration cannot be limited this way

`/users/register` is a LiveView. The form submit is a LiveView event sent over
the shared `/live/websocket` connection, not a `POST /users/register` request.
Cloudflare therefore cannot count account creations with a rule on the
registration path.

A Cloudflare rule on `GET /users/register` only limits page opens; a bot can
open one page and submit many registrations over the socket. If registration
spam becomes a problem, add an application-level registration throttle keyed by
`ChesstrainerWeb.ClientAddress.from_socket/1`, and/or add Cloudflare Turnstile
to the form.

While `PRELAUNCH=true`, registration is blocked entirely by the prelaunch plug
and LiveView mount redirect.

## 4. Why not fail2ban for HTTP?

fail2ban needs the raw client address to build a firewall rule. The application
deliberately logs only a boot-scoped HMAC, and this deployment sits behind
Cloudflare. Banning the address that reaches the origin would ban Cloudflare
edges, not attackers.

fail2ban remains useful for services that terminate connections directly on the
VPS, such as SSH. It is not part of the HTTP login defence.
