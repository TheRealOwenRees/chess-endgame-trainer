# Error-state verification

The #162 checklist, walked on 2026-11-13 against a local production-like build.
Failures were filed as #171 and fixed in the follow-up for that issue; this page
records the verification run, not the current state. It is linked from the
audit.

## Method

- **Build:** `MIX_ENV=prod` `mix phx.server` on `127.0.0.1:4010`, commit
  `021e412` plus this branch's documentation.
- **Database:** a scratch `postgres:18.6` on port 55432. Empty at first, then
  one confirmed user and one 8+ piece endgame (inserted directly, because the
  admin changeset rejects positions beyond seven pieces).
- **Configuration:** `PRELAUNCH=false`, `MAILING_LIST_ENABLED=true`,
  `TABLEBASE_PATH` pointing at a missing directory, dummy SES credentials.
- **Forced failures:** Postgres stopped, missing tablebase directory, empty
  puzzle pool, expired reset and confirmation tokens (backdated
  `users_tokens.inserted_at`), stale and invalid mailing-list forms, guest
  budget exhausted, unknown public play code.
- **Observation:** `curl` for controller-rendered pages, headless Chrome over
  the DevTools Protocol for LiveView-connected pages, and `mix test` for the
  interactive states that need a click. Each row names its evidence.
- **Not forced:** a real Lichess 429 (the cooldown and classifier paths were
  exercised by the tests), a crash after connect, and the two admin-only import
  leaks (code inspection and tests). The first run rejected the socket origin
  because `PHX_HOST` defaulted to `example.com`; setting `PHX_HOST=127.0.0.1`
  fixed it. That was local configuration, not a product finding.

## Results

| Checklist row | Result | Evidence |
|---|---|---|
| T1 cooldown | **pass** | LiveView test: mount with a cooldown shows "Tablebase cooling down"; Retry re-fetches and returns to play. |
| T2 429 | **pass** | LiveView test: classifier maps 429 to "Tablebase rate-limited"; HTML carries no `429`, `too_many_requests` or upstream body. |
| T3 not covered | **pass** | Prod run: guest page with a 12-piece endgame shows "Position not covered… can't be graded", no `not_covered` in the DOM, Next puzzle or back available. |
| T4 generic | **pass** | LiveView test: classifier returns "Tablebase unavailable"; the reason is logged and never rendered. |
| T5/T6 load and reply failure | **pass** | T5 covered by the cooldown-at-mount test and Retry. T6 shares the blocked panel and `reset/1` path; not separately forced. |
| T8 invalid FEN | **fail** | Existing test: the flash still contains the client message and the raw FEN. #171. |
| S1/S2/S3/S5 empty pools | **pass** | S1 prod: Medium picker shows the in-page empty state and Retry. S5 prod: guest shows "No endgames are available yet" and Retry. S2/S3 tests: exhausted state, Retry and Change difficulty. |
| S4 guest limit | **pass** | Prod run: five visits exhaust the budget; the wall shows the reset time, Sign up free and Log in. |
| A1 reset token | **pass** | Prod run: an expired token flashes "Reset password link is invalid or it has expired." on the log-in page, with Forgot your password available. |
| A2 confirmation token | **fail** | Prod run: an expired token flashes "User not found or token is invalid." and lands on registration, not log in. #171. |
| A3/A4 login | **pass** | Tests: invalid credentials use one message; the throttle reports the remaining minutes. |
| M1–M5 mailing list | **pass** | Prod run: invalid confirmation link, removed address, stale form, invalid email and an SES send failure each show their specific copy with the form reachable. |
| W1/W2 404 and 500 | **pass** | Prod run: styled 404 for an unknown path; with Postgres stopped, `/` returns the styled 500 with no exception or stacktrace. |
| W3 crash | **fail** | The server-error banner has no reload action; a repeating crash has no manual escape. Not separately forced; same banner as W4. #171. |
| W4 disconnect | **pass** | Observed "Something went wrong! Attempting to reconnect" while the socket was rejected, with automatic retries; the banner hides on reconnect. |
| W5 database down | **pass** | Prod run: `/health` returns 503 `db:down`; `/` returns the 500 page. Note the loop: the home link also needs the database, so it 500s too. |
| D1/D2 export | **fail** | Prod run: an export with the database stopped returns the 500 page (no export-specific copy); `/users/profile/export/xml` returns plain text "Unknown export format". #171. |
| H1 empty-database home | **fail** | Prod run: the fallback board renders, but "Try today's puzzle" points at the auth-gated `/endgames`. #171. |
| X1 unknown play code | **pass** | Prod run: `/endgames/nope/play` returns the styled 404 page. This corrects the audit's earlier claim that it 500ed. |
| X2/X3 admin leaks | **fail** | Code inspection and tests: both importer messages still interpolate `inspect(reason)`. Not forced. #171. |

## Tally

- 14 checklist rows pass, 6 fail (8 individual regressions, because D1/D2 and
  X2/X3 share a row).
- Every failure row is a state that was already listed as "improve" in the
  audit and was outside #163; no new regression came from the #163 changes.
- The regressions are filed together in #171 rather than fixed silently.
