# Logging

Production writes one JSON object per line to standard output, which systemd
captures in journald. Development and test keep the readable
`[level] message` formatter.

## Configuration

`config/prod.exs` swaps the default handler's formatter for
`Chesstrainer.JSONLogFormatter`; nothing else changes per environment. The
formatter adds no runtime dependency beyond `Jason`, which the app already uses
for Phoenix JSON.

## Line shape

```json
{
  "timestamp": "2026-11-10T21:36:28.489000Z",
  "level": "error",
  "message": "GET /endgames 500 in 12.5ms",
  "request_id": "F7x...",
  "method": "GET",
  "path": "/endgames",
  "status": 500,
  "duration_ms": 12.5,
  "error": {
    "kind": "RuntimeError",
    "reason": "bad thing",
    "stacktrace": ["lib/foo.ex:10: Foo.bar/1"]
  }
}
```

`timestamp`, `level` and `message` are always present. Metadata keys are
flattened into the object; reserved internal keys (`time`, `gl`, `report_cb`,
`error_logger`, `exception`, `stacktrace`, `crash_reason`, `reason`, `kind`)
are either unpacked into the line or omitted. Fixed fields win over metadata
with the same name.

| Field | When | Meaning |
|---|---|---|
| `timestamp` | always | ISO-8601 UTC, microsecond precision |
| `level` | always | `debug`, `info`, `notice`, `warning`, `error`, … |
| `message` | always | Rendered log message, truncated to 8 KiB |
| `request_id` | request-scoped logs | `Plug.RequestId` value, including LiveView processes |
| `method`, `path`, `status`, `duration_ms` | access lines | One HTTP request; no query string or body |
| `error.kind` | exceptions/crashes | Exception module, or the crash reason's kind |
| `error.reason` | exceptions/crashes | `Exception.message/1` or an inspected reason |
| `error.stacktrace` | exceptions/crashes | Array of formatted frames, capped at 50 |
| everything else | as supplied | Flattened atom metadata, sanitised and redacted |

Exceptions (`Logger.error(..., exception: ..., stacktrace: ...)`) and OTP crash
reports (`meta.crash_reason`, including Bandit request crashes and GenServer
terminations) become the `error` object. Stacktrace frames are an array of
strings so `jq -r '.error.stacktrace[]'` prints them readably.

## Redaction

The formatter redacts:

- metadata keys named `email`, `*_email`, `email_address`, `contact_email` or
  `recipient`;
- any email-shaped string anywhere in metadata, nested `params`, or the rendered
  message;
- credentials in `password`, `secret`, `token`, `authorization`, `cookie`,
  `api_key`, `private_key` and `credential` keys;
- `token=...`/`password=...` assignments in messages.

Path segments of 20 or more URL-safe characters (reset/confirmation tokens,
UUIDs) are replaced with `[REDACTED]` in access lines. Query parameters and
request bodies are never logged.

## Access lines

`ChesstrainerWeb.RequestLogger` listens to `[:phoenix, :endpoint, :stop]` and
emits one `:info` line per HTTP request that reaches the endpoint, including a
LiveView's initial request. Phoenix's own endpoint start/stop pair is disabled
with `log: false` in `ChesstrainerWeb.Endpoint` so there is exactly one line.

`ChesstrainerWeb.Plugs.PutRequestId` copies `Plug.RequestId`'s id into the
session, and `UserAuth.mount_current_scope/2` puts it into `Logger.metadata/1`,
so logs from the LiveView process keep the id after the HTTP request ends.

## Writing logs

Normal `Logger` calls need no changes. Atom metadata keys are flattened into the
JSON object:

```elixir
require Logger

Logger.info("tablebase cache miss", table: :tablebase, key: key)
Logger.warning("tablebase fetch failed", status: 503, reason: reason)
```

For a caught exception, pass the exception and stacktrace so the formatter can
build the `error` object:

```elixir
Logger.error("cache backup failed", exception: exception, stacktrace: __STACKTRACE__)
```

For background work, wrap the body so `{:error, reason}` returns, throws, exits
and crashes all produce a log line:

```elixir
Task.Supervisor.start_child(Chesstrainer.Cache.BackupSupervisor, fn ->
  Chesstrainer.Background.run("send digest", [user_id: user.id], fn ->
    send_digest(user)
  end)
end)
```

Prefer identifiers such as `user_id` or `table` over emails, and never log
params or request bodies. The formatter is a safety net, not a licence to log
PII.

## Authentication events

`ChesstrainerWeb.UserSessionController` emits warning lines consumed by
host-level tooling such as fail2ban:

| Message | Metadata | Meaning |
|---|---|---|
| `auth.login.failed` | `reason` (`invalid_credentials` / `unconfirmed`), `ip` | A password login failed. |
| `auth.login.throttled` | `reason` (`ip` / `login`), `ip` | The address or login bucket blocked the attempt before bcrypt. |

`ip` is a boot-scoped HMAC of the client address, not the address itself. The
raw login identifier and password are never included. The login throttle is
configured in `config/config.exs` and defaults to five failures per login and
ten per address in a fifteen-minute window.

## Querying logs

`journalctl` prints the raw line only with `-o cat`; the default output wraps it
in journald fields. Install `jq` once on the VPS with
`sudo apt-get install -y jq`, then:

```sh
# Pretty-print recent lines
sudo journalctl -u chesstrainer -o cat -n 50 --no-pager | jq .

# Errors only
sudo journalctl -u chesstrainer -o cat --since "1 hour ago" \
  | jq 'select(.level == "error")'

# Everything from one request id
sudo journalctl -u chesstrainer -o cat \
  | jq 'select(.request_id == "REQUEST_ID")'

# Crash reason and stacktrace
sudo journalctl -u chesstrainer -o cat \
  | jq -r 'select(.error) | "\(.timestamp) \(.error.kind): \(.error.reason)\n\((.error.stacktrace // []) | join("\n"))"'

# Slow requests
sudo journalctl -u chesstrainer -o cat \
  | jq 'select(.duration_ms > 1000) | {timestamp, method, path, status, duration_ms}'

# Most common error kinds in the current boot
sudo journalctl -u chesstrainer -o cat -b \
  | jq -r 'select(.error.kind) | .error.kind' | sort | uniq -c | sort -rn
```

`Plug.RequestId` also returns the id in the `x-request-id` response header, so a
user can report the id from a failed request and you can filter straight to it.

## Local checks

The formatter tests run without a production release:

```sh
mix test test/chesstrainer/json_log_formatter_test.exs \
  test/chesstrainer/background_test.exs \
  test/chesstrainer_web/request_logger_test.exs
```

To render one event without touching the Logger configuration:

```sh
mix run --no-start -e '
event = %{
  level: :error,
  msg: {:string, "boom"},
  meta: %{
    time: System.system_time(:microsecond),
    request_id: "req-1",
    email: "user@example.com",
    exception: %RuntimeError{message: "bad"},
    stacktrace: [{Foo, :bar, 1, [file: ~c"lib/foo.ex", line: 10]}]
  }
}
IO.puts(Chesstrainer.JSONLogFormatter.format(event, %{}))
'
```

That prints one JSON line with the email redacted and the exception unpacked
into `error`.

## Background work audit (#107)

Checked:

- `Chesstrainer.Cache` scheduled backup: `Task.Supervisor.start_child` ignored
  the task's return value and `Persist.backup/1` returns `{:error, reason}`
  without logging. Now wrapped in `Chesstrainer.Background.run/3`, which logs
  `{:error, reason}` returns and crashes (with exception, reason and
  stacktrace). A failure to start the task is logged too.
- `Chesstrainer.Cache.Persist.restore/1`: an unreadable backup was silently
  skipped. It now logs a warning with the reason and starts with an empty cache.
- `Chesstrainer.Endgames.Tablebase.Parser`: Lichess 5xx and network failures
  were returned to the caller (which shows a flash) but never logged. They now
  log a warning with the status or reason. 429 cooldowns stay quiet because they
  are expected.
- `Mix.Tasks.Tablebase.Fetch`: already aborts loudly with `Mix.raise` on HTTP or
  network failure; no change.
- Email delivery: sends are synchronous and their error is returned to the
  controller, so nothing is silent today. Future background sends should use
  `Chesstrainer.Background.run/3`.

## Reading logs on the VPS

See the "Reading production logs" and "Keep the journal" sections in
[`deploy/README.md`](../deploy/README.md).
