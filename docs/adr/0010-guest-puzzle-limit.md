# Guest puzzles are capped per UTC day by a hashed address

`/guest-train` gives anonymous visitors 5 puzzles per UTC day. The budget is per
client address, but the address is never stored: the limiter keys an in-memory
ETS table by `HMAC-SHA256(boot_secret, "<gregorian_day>|<address>")`. The secret
is generated when the node boots, so digests are not stable across restarts and
cannot be correlated with anything else. The table is swept when the day rolls
over, and no entry is ever written to the database, a log, or a backup.

## Why a daily UTC reset

A fixed 00:00 UTC boundary makes the rule easy to state ("5 free puzzles a
day"), gives every visitor the same reset instant, and removes the need for
per-entry timestamps: the UTC date is part of the key, so yesterday's entries
simply stop matching. That also means the stored data's lifetime is bounded by
the calendar day.

## Why not an IP address

The raw address is never persisted; only the digest is, and only until the day
rolls over or the node restarts. This is abuse prevention with data
minimisation, not tracking, and needs no cookie or client-side storage. The
processing is disclosed in the privacy policy (see #87).

## Consequences

- Visitors behind one NAT share a budget. Masking to a subnet would make that
  worse, so the full address is hashed.
- The budget lives in one node's memory: a restart resets it, and a second node
  would keep its own. Move the counter to Postgres or Redis if that matters.
- The unit being metered is a puzzle load, not a move. A LiveView reconnect
  re-runs the connected mount and therefore consumes one puzzle.
- Retry and review never consume a puzzle because they reuse the loaded
  position.
- Signed-in visitors are redirected to `/train` and are never metered.
- Behind a proxy, set `TRUST_FORWARDED_FOR=1` and make sure the proxy overwrites
  or appends `X-Forwarded-For`; otherwise every visitor shares the proxy's
  budget. `GUEST_PUZZLE_LIMIT` changes the daily allowance.
