# User-facing error states

What a player sees when something fails, with a verdict for every state and the
concrete change each one needs. This is the audit required by #162; #163
implements the tablebase and empty-pool items, and #164 walks the sign-off
checklist on a production-like build.

Verdicts:

- **keep** — the state is honest, recoverable and leak-free as it stands
- **improve** — a state exists but needs different copy, a recovery action, or
  both
- **add** — there is no user-facing state today

"Internal detail" means an exception term, an `inspect/1` result, a raw HTTP
status body, a stacktrace, or a raw FEN appearing in rendered HTML.

## Play and tablebase

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| T1 | Cooldown | A previous 429 put Lichess in cooldown; `Tablebase.new/1` returns `{:cooldown, ms}` (`play_core.ex:386`) | Panel headed **Tablebase unavailable**, body "The tablebase is rate-limited. Try again in about Ns."; move hint "The tablebase is unavailable, so moves cannot be entered."; **Reset** | improve | Heading per failure class ("Tablebase cooling down"), keep the countdown, and relabel Reset to **Retry** while blocked. Fold into #163. |
| T2 | Lichess 429 | Lichess returns 429; the parser records a cooldown (`tablebase/parser.ex:69`) | Same panel; "The tablebase is rate-limited. Try again in a minute." | improve | Same class as T1, with the real countdown once known. Never show `429` or the response body. Fold into #163. |
| T3 | Position not covered | More than seven pieces, Lichess 404, or `:not_covered` (`play_core.ex:394-401`) | Panel headed **Tablebase unavailable**, body "This position is not covered by the tablebase."; **Reset** | improve | Say the puzzle cannot be graded, and offer **Try another puzzle** (session) or **Browse endgames** (single). Retry is futile here, so do not present it as the primary action. Fold into #163. |
| T4 | Generic tablebase failure | 5xx, transport error, malformed response (`play_core.ex:403`) | **"The tablebase is unavailable (#{inspect(reason)})."** | improve | Replace with "The tablebase is unavailable right now. Try again in a moment." and log the reason. This is the leak #163 calls out. Also applies to the review panel's `review_blocked` copy. |
| T5 | Load failure at session start | `Tablebase.new/1` fails in `PlayCore.init/2` → `load_attempt/1` | Board non-interactive; blocked panel and reason; **Reset** | improve | Class-correct copy plus **Retry**; `reset/1` already re-fetches, so this is a label and copy change. Fold into #163. |
| T6 | Fetch failure for the opponent's reply | `start_opponent_reply/2` cannot fetch the new position (`play_core.ex:457`) | Play stops; blocked panel; the move already played is still on the board; **Reset** | improve | Explain that the puzzle is paused and **Retry** resumes from the current position. Fold into #163. |
| T7 | Move while blocked | A move event arrives while `status == :blocked` (`play_core.ex:76`) | Flash "The tablebase is unavailable, so this move cannot be graded." | keep | Defensive guard; the board should already be non-interactive. #164 asserts that. |
| T8 | Invalid FEN from the board hook | `chess_fen_invalid` (`play_core.ex:184`) | Flash **"Endgame FEN is invalid and the board cannot be loaded: #{message} (#{fen})"** | improve | Generic copy ("The board couldn't load this position. Reset to try again."), log the details, and keep **Reset** visible. Leak: client message and raw FEN. |

## Sessions and puzzle pools

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| S1 | No puzzles available | `Puzzles.next_endgame/3` returns `nil` on start (`train.ex:201`) | Flash error "No puzzles are available right now."; the difficulty picker stays behind it | improve | Replace the flash with an in-page state inside the picker: what happened, **Retry**, and a way to pick another difficulty. Fold into #163. |
| S2 | No more puzzles at this difficulty | `next_endgame` returns `nil` with `exclude_ids` (`train.ex:232`) | Flash info "No more puzzles at this difficulty."; the finished puzzle and **Next puzzle** remain | improve | In-page end-of-run panel: "You've finished every puzzle at this difficulty" with **Retry**, **Change difficulty** (stop session) and the existing Stop session. Hide or disable Next. Fold into #163. |
| S3 | Guest: no more puzzles | Guest `next_puzzle` finds nothing (`guest_train.ex:137`) | Flash info "No more puzzles are available right now." | improve | In-page state with **Retry** and the sign-up/log-in actions, matching the guest-limit panel's tone. Fold into #163. |
| S4 | Guest limit reached | `GuestLimits.take/1` returns `{:limit_reached, ms}` (`guest_train.ex:45-70`) | In-page panel: used N free puzzles, reset time, **Sign up free**, **Log in** | keep | This is the reference state for tone and recovery. |
| S5 | Guest pool empty on load | Random endgame is `nil` (`guest_train.ex:98`) | In-page "No endgames are available yet. Please check back soon." | improve | Add a **Retry** action so the state is not a dead end. Fold into #163. |

## Accounts and email

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| A1 | Reset token invalid or expired | `get_user_by_reset_password_token/1` returns `nil` (`reset_password.ex:66`) | Flash "Reset password link is invalid or it has expired." then the log-in page, where **Forgot your password?** is available | keep | Honest and recoverable in two clicks. |
| A2 | Confirmation token invalid or expired | `Accounts.confirm_user/1` returns `:error` (`user_confirmation_controller.ex:17`) | Flash **"User not found or token is invalid."** then the registration page | improve | Say "That confirmation link is invalid or has expired." and send the user to log in, where an unconfirmed account triggers a fresh confirmation email. No "user not found" phrasing. |
| A3 | Invalid credentials | `get_user_by_login_and_password/2` returns `nil` | Flash "Invalid email, username or password"; email is prefilled | keep | Deliberately identical for unknown and wrong-password logins, so it does not enumerate accounts. |
| A4 | Login throttle | 5 failures per login or 10 per address in 15 minutes (`LoginThrottle`) | Flash "Too many attempts. Try again in N minutes." | keep | Accurate countdown, no account information. |

## Mailing list

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| M1 | Confirmation link invalid or expired | Token fails verification (`mailing_list_controller.ex:36`) | Flash "That confirmation link is invalid or has expired." → `/#mailing-list` | keep | The signup form is on the destination page. |
| M2 | Confirmed address no longer subscribed | `MailingList.confirm/1` returns `:not_found` (`:52`) | Flash "That address is no longer on the mailing list. Please sign up again." → `/#mailing-list` | keep | Actionable and specific. |
| M3 | Stale signup form | `MailingListFormToken.verify/1` fails (`:126`) | Flash "Please refresh the page and try again." → `/#mailing-list` | keep | The form is on the page; refresh is the fix. |
| M4 | Invalid email | Missing or invalid address (`:132`) | Flash "Enter a valid email address." | keep | Specific and actionable. |
| M5 | Confirmation email send failure | `Notifier.deliver_confirmation_instructions/2` returns an error (`:111`) | Flash "We couldn't send the confirmation email. Please try again." | improve | Keep the copy, add "If it keeps happening, email …" from `Branding.support_email/0`, and log the reason — the controller currently discards it. |
| M6 | List closed / honeypot / already subscribed | Feature flag, honeypot, or existing address | "The mailing list isn't open yet." / success copy / "You're already on the mailing list." | keep | Closed and honeypot are deliberate; the existing-address message is honest. |

## Site-level

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| W1 | 404 | Unknown route (`ErrorHTML`, catch-all route) | Styled page: "This page isn't on the board", **Back to home**, plus **Browse puzzles** for premium users | keep | Uses the shared `error_page/1`. |
| W2 | 500 | Controller or render crash | Styled page: "Something went wrong", **Back to home**, **Browse puzzles**, support email | keep | Honest, no exception detail. |
| W3 | LiveView crash | Raise in `mount` or `handle_event` | Mount crash → the 500 page. A crash after connect → the **"Something went wrong!"** banner, automatic reconnect, no manual action | improve | Add a **Reload** action (and keep home) to the server-error banner so a crash that repeats on reconnect has an escape. The banner lives in `layouts.ex:274`. |
| W4 | Disconnect | Socket or network loss | **"We can't find the internet"** banner with a spinner; hides on reconnect | keep | Automatic recovery, no action needed. |
| W5 | Database unavailable | Postgres stopped or pool exhausted | DB-backed pages and LiveView mounts raise → the 500 page; `/health` returns 503 | keep | The 500 page is the right state, but note the loop: the home page also needs the database, so "Back to home" fails too. The probe is the operational signal. No app change proposed here. |

## Data and landing

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| D1 | Export failure | `Attempts.list_attempts_for_user/1` raises in `UserDataController.export/2` | The 500 page, with no export-specific explanation | improve | Rescue, log, and redirect to `/users/profile/data` with "We couldn't build your export. Try again; if it keeps failing, email …". |
| D2 | Unknown export format | `/users/profile/export/<anything else>` | Plain text `404 "Unknown export format"` with no chrome, links, or home | improve | Return the styled 404 page instead. |
| D3 | Export of an empty account | No attempts | CSV with the header and an empty row; JSON with an empty list | keep | Deliberate and documented by the shape. |
| H1 | Home page with an empty database | No endgames (`PageController.home/2`) | Fallback KRK board, "Featured position", "0 players training", and a **Try today's puzzle** button pointing at `/endgames` | improve | When `active_endgame` is `nil`, do not send the visitor to an auth-gated page with no puzzles: point the call to action at `/guest-train` (which has its own empty state) or disable it with "New puzzles are coming". |

## Admin surfaces (extra)

| ID | State | Trigger | What the user sees today | Verdict | Action |
|---|---|---|---|---|---|
| X1 | Unknown public play code | `/endgames/:code/play` with a code that does not exist (`play.ex:79`) | `get_endgame_by_public_code!/1` raises → the 500 page | improve | Fetch without the bang and render the 404 page (or redirect to `/endgames` with a flash). A stale link is not a server error. |
| X2 | Bulk import lookup crash | `handle_async` exits (`import.ex:271`) | Flash **"Could not look up the FENs: #{inspect(reason)}"** | improve | Generic copy plus a logged reason. Admin-only, but still an internal leak. |
| X3 | Bulk import tablebase load failure | `Local.check/0` returns an unexpected error (`import.ex:287`) | **"Local tablebase failed to load: #{inspect(reason)}"** | improve | Generic copy plus a logged reason. Admin-only, but still an internal leak. |

## Internal-detail leaks

These are the only places where an exception term, a raw HTTP status or a raw
FEN can reach rendered HTML. T4 is the one #162 calls out; the rest are smaller
but real.

| Where | Leak | Fix |
|---|---|---|
| `play_core.ex:404` | `inspect(reason)` in the blocked panel | T4 |
| `play_core.ex:189` | client message and raw FEN in a flash | T8 |
| `import.ex:271` | `inspect(reason)` in a flash | X2 |
| `import.ex:287` | `inspect(reason)` in the tablebase status | X3 |
| `user_data_controller.ex:21` | plain-text "Unknown export format" | D2 |

Server logs already carry the real reasons, so none of these fixes lose
diagnostic information.

## Sign-off checklist

For #164 to walk against a production-like build. Every row passes only if the
state offers **retry or a way home** and rendered HTML contains no exception,
stacktrace, raw error term, or raw FEN.

- [ ] **T1 cooldown** — force a cooldown: class-correct heading, countdown, Retry re-fetches.
- [ ] **T2 429** — make Lichess return 429: rate-limit copy, no `429` or response body.
- [ ] **T3 not covered** — play a position with more than seven pieces: explanation, another puzzle or home, no futile Retry.
- [ ] **T4 generic** — make Lichess fail (network off or 5xx): generic copy, Retry works when it recovers, no `inspect`.
- [ ] **T5/T6 load and reply failure** — start a puzzle and lose the tablebase mid-game: paused explanation, Retry resumes.
- [ ] **T8 invalid FEN** — force `chess_fen_invalid`: no client message or raw FEN, Reset visible.
- [ ] **S1/S2/S3/S5 empty pools** — empty the pool: in-page states on train and guest, Retry and change-difficulty reachable.
- [ ] **S4 guest limit** — exhaust the guest allowance: panel, reset time, sign-up and log-in reachable.
- [ ] **A1 reset token** — use an expired link: message, log-in page, forgot-password reachable.
- [ ] **A2 confirmation token** — use an expired link: message, log-in page, fresh confirmation email on next login.
- [ ] **A3/A4 login** — wrong password and throttled login: no account enumeration, countdown.
- [ ] **M1-M5 mailing list** — expired confirmation, stale form, invalid address, send failure: specific copy and the form reachable.
- [ ] **W1/W2 404 and 500** — unknown path and forced crash: styled page, home and browse reachable, no exception.
- [ ] **W3 crash** — raise in a `handle_event`: reload action reachable.
- [ ] **W4 disconnect** — drop the socket: reconnect banner and automatic recovery.
- [ ] **W5 database down** — stop Postgres: 500 pages, `/health` 503, no stacktrace; note that home is also down.
- [ ] **D1/D2 export** — force an export error and an unknown format: flash or 404 page, home reachable.
- [ ] **H1 empty database** — empty the pool: home renders, call to action is not an auth-gated dead end.
- [ ] **X1 unknown play code** — open a stale link: 404 page, not a 500.
- [ ] **X2/X3 admin leaks** — force an import crash and a tablebase error: no `inspect` output.

## Fix list

Fold into **#163** (tablebase and empty-pool recoverability): T1, T2, T3, T4,
T5, T6, S1, S2, S3, S5.

Separate changes, each independently testable:

- **T8** — generic invalid-FEN flash; log the details.
- **A2** — confirmation-token copy and destination.
- **M5** — support fallback on send failure; log the reason.
- **W3** — reload action in the server-error banner.
- **D1** — rescue export errors into a flash on the data tab.
- **D2** — styled 404 for unknown export formats.
- **H1** — empty-database call to action.
- **X1** — 404 instead of 500 for an unknown public code.
- **X2/X3** — generic admin import copy; log the details.

No code changes are part of this audit.
