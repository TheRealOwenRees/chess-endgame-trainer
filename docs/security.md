# Login and edge security

The login surface is protected in layers. The application throttle is the
primary control; Cloudflare is the edge backstop for volume. There is no
origin-level fail2ban for HTTP logins, because it would require storing raw IP
addresses and would ban Cloudflare edge addresses on this deployment.

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

In the Cloudflare dashboard, add a rate limiting rule for login POSTs:

| Setting | Value |
|---|---|
| Name | Login POST flood |
| Expression | `(http.request.method eq "POST" and http.request.uri.path in {"/admin/log-in" "/users/log-in"})` |
| Characteristic | IP |
| Period | 10 seconds |
| Requests | 10 |
| Action | Block |
| Duration | 10 minutes |

If the plan only offers a 10-second period, that is fine. This rule is an
anti-flood control; the application's 5-per-login and 10-per-address limits in a
15-minute window remain the real credential controls. A slow attacker staying
under 10 requests per 10 seconds still hits the application throttle.

Tune the threshold upward if legitimate users behind shared NAT are affected.

Also consider:

- a broader site-wide rule such as 100 requests per 10 seconds per IP with a
  managed challenge (adjust for page assets and LiveView traffic);
- Cloudflare Bot Fight Mode and the managed WAF ruleset;
- Under Attack Mode during an active incident.

Availability and rule counts depend on the Cloudflare plan. If rate limiting
rules are not available, use Bot Fight Mode, managed challenges and Under
Attack Mode instead.

## 4. Why not fail2ban for HTTP?

fail2ban needs the raw client address to build a firewall rule. The application
deliberately logs only a boot-scoped HMAC, and this deployment sits behind
Cloudflare. Banning the address that reaches the origin would ban Cloudflare
edges, not attackers.

fail2ban remains useful for services that terminate connections directly on the
VPS, such as SSH. It is not part of the HTTP login defence.
