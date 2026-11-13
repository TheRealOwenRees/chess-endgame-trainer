# Launch observability is the probe, honest error states, and the runbook

_Status: accepted._

At launch, observability means three things and no more: an external check that
the public app answers, error states that are honest and recoverable, and a
written runbook for when either fails. Everything else is deferred with a named
trigger, so the gaps are explicit rather than ambient.

## The launch bar

- **Probe.** A healthchecks.io check with a two-minute period and grace, fed by
  an on-box prober with off-box alerting (#160, #161). It curls the public
  `/health` through Cloudflare, so DNS, TLS, Caddy, the origin allowlist,
  Phoenix and one Postgres query are covered. The loopback cross-check in a
  failure body is evidence only. The prober shares a host with the app, so host
  death is caught by silence, not by a ping.
- **Error states.** The audit (#162) and its fixes (#163), verified by #164.
  Every failure mode has copy and a retry or a way home; exception details and
  raw error terms do not reach the page.
- **Runbook.** `deploy/README.md` §Monitoring and alerting: the check, install,
  what `/health` proves and does not, Beszel's blind spot, the drills, and the
  dated drill log.

## Deferred, with triggers

- **Error tracking (#109, GlitchTip/Sentry).** Deferred because JSON logs
  already carry the crash reason and stacktrace per request, and there is no
  traffic to aggregate over. Revisit when the first production 500 cannot be
  diagnosed from its journal line (missing or truncated stacktrace), or a user
  reports an error without a request id, or unexplained errors exceed roughly
  50 a day and per-line grep stops being practical.
- **Metrics and LiveDashboard (#111).** Deferred because Beszel covers host
  resources and the probe covers the HTTP contract. Revisit when a capacity
  question needs a number neither can answer (database pool saturation, p95
  latency, queue depth), or daily active users pass 100, or a performance
  incident takes more than an hour to localise.
- **Off-box log shipping and error-rate alerts (#140).** Deferred because
  journald is persistent on the host and the probe alerts on downness. Revisit
  when an alert must fire on a log pattern (error rate, authentication
  failures), or the journal retention budget cannot cover a 30-day
  investigation, or the host is rebuilt and local logs would be lost in the same
  incident.

## Why journald and backups are enough at launch

Persistent journald (`Storage=persistent`, `SystemMaxUse`) holds one JSON object
per line: crashes carry a reason and stacktrace, access lines carry status and
duration, and token-shaped paths, emails and credentials are redacted. Off-box
encrypted backups cover the data.

The accepted risk: losing the host loses the logs with it, and there is no
aggregate error rate. At launch that is acceptable — one host, one operator,
low traffic, and an incident is diagnosed from the journal on the box or from
the probe's alert body. The triggers above are the point at which that risk
stops being acceptable.

## Consequences

- Investigation starts with `journalctl -u chesstrainer -o cat | jq`, not a
  dashboard.
- Error tracking, metrics and log shipping stay explicit backlog items with
  triggers rather than ambient gaps.
- The probe is an on-box prober with off-box alerting; it is not external
  uptime monitoring and the runbook says so.
