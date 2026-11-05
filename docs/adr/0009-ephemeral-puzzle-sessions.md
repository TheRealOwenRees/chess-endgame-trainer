# Puzzle sessions are ephemeral and share one play surface

A session — one continuous spell of puzzle play, started by choosing a
difficulty — carries a start time and a rating baseline for the timer and
rating-gain monitor, and lives only in the running `Train` LiveView. Nothing is
persisted: attempts are still recorded per endgame, but the session itself has
no table.

The alternative was to keep `EndgameLive.Play` as the play surface and navigate
from puzzle to puzzle (e.g. `/endgames/:code/play?session=...`), carrying the
session in the URL or a short-lived server token. Navigation kills the LiveView
socket, so the timer, per-puzzle times, baseline and completed count would all
have to be carried or re-derived; that fights the "ephemeral" decision and
leaks session state into URLs. Instead the session owns one socket and swaps the
current endgame in place, which keeps every session value in one place.

To avoid a second copy of the move grading and best-line review, the play
surface (board, grading, opponent reply, review, retry) is extracted into a
shared module used by both `EndgameLive.Play` (standalone, optional auth, used
by daily/curated deep links) and the new `EndgameLive.Train` (session, login
only). Both keep their own `handle_event` entry points, which delegate to the
shared logic, so the existing play tests and event contract are unchanged.

## Consequences

- `/endgames/:public_code/play` stays a standalone play surface; `/train` is the
  session front door.
- Session state (difficulty, start time, baseline, completed count, per-puzzle
  timing) never leaves the `Train` socket and disappears when the page closes.
- Difficulty is relative to the current user's rating, not an absolute property
  of an endgame; its band width is a config constant.
