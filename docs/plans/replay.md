# Replay: post-attempt review of a played puzzle

Goal: after a puzzle ends (solved or failed), let the user step through the game
they just played, see the best move at each position, and — where they went
wrong — follow the optimal line to see how it should have gone.

## Definition of done

- On `:solved`/`:failed`, an explicit **Review** button appears alongside
  "Try again". Clicking it enters read-only review mode.
- The move list shows the **full game** — the user's moves *and* the opponent's
  replies — with the user's plies color-coded by grade (optimal / winning /
  losing), result-aware for draw puzzles.
- Clicking any ply (or using prev/next) repositions the board to that position.
- At every reviewed position, the best move(s) for the side to move are shown.
- On a failed attempt, the losing move is highlighted with the best alternative,
  and **"Play best line"** steps through the tablebase's optimal continuation.
- Review is **ephemeral**: it lives in socket `assigns` and is lost on refresh.
- Review is **read-only**: no resuming play from a replayed position.

## Decisions (see GLOSSARY.md, docs/adr/)

- Review is entered via an explicit button, not auto-entered on finish.
- **LiveView owns the move history**; the board is a pure FEN display driven by
  the existing `set_fen` hook (our own solution now; see "Future" below).
- The played line is recorded with a per-ply tablebase snapshot, so best moves
  on the played line need no re-query. Off-line "Play best line" positions fetch
  on demand and degrade gracefully under rate-limit/cooldown.
- Review is ephemeral and read-only; "Try again" starts a fresh attempt.

## Work breakdown

### 0. Rating default (independent)
- Add `default: 1500` to `field :rating` in `lib/chesstrainer/endgames/endgame.ex`
  (matches the DB migration default). The new-endgame form then auto-fills 1500.

### 1. Record the full game during play (`EndgameLive.Play`)
- Replace `move_list` (SAN strings) with a ply list; each ply records
  `{san, uci, fen_after, side, grade, tablebase_snapshot}`.
- Append the opponent's reply (currently discarded in `opponent_reply_applied` /
  `start_opponent_reply`) to the same list.
- Snapshot the `%Tablebase{}` used at each position (the one already fetched for
  grading / reply selection) onto its ply.

### 2. Review state + navigation
- Add `:review` status and a current-ply index; a "Review" button transitions
  `:solved`/`:failed` → review mode.
- Move list: render full game, each ply `phx-click`-able; prev/next controls and
  arrow-key navigation.
- On ply selection, push that ply's FEN to the board via the existing `set_fen`
  handler.

### 3. Best-move panel
- At the reviewed position: show the best move(s) from the ply's snapshot
  (reuse `best_move_text/1` logic, extended to a list).
- On the failing ply: highlight it red, show "You played X; best was Y".

### 4. "Play best line" (optimal continuation)
- From any reviewed position, offer "Play best line": step forward through the
  tablebase's best moves, fetching `Tablebase.new/1` on demand for positions off
  the played line.
- On `{:cooldown, _}` / `{:error, _}`, show a graceful "tablebase unavailable
  here" note and stop the line, without breaking the rest of review.

### 5. Move-list rendering
- Full game with grade colors; draw-puzzle-aware labels ("keeps the draw" /
  "throws away the draw" rather than "winning"/"losing").

## Future: chessground-native move list (Approach 2)

Our current solution keeps the move history in LiveView and treats the board as
a FEN display. A later migration to the lichess-style approach would:

- Feed chess.js the full move history and run chessground in `viewOnly` mode.
- On ply click, read `chess.history({verbose:true})[i]` and `ground.set({fen})`
  client-side, removing the per-ply server round-trip.

The move-list component itself is not part of chessground (it lives in lichess's
`ui`). **Licensing**: chessground is GPL-3.0-or-later (already a dependency, so
reusing more of it adds no new obligation). lichess's `ui` is AGPL-3.0-or-later
(network copyleft — obligations trigger merely by serving the app). So the
migration stays license-clean only if we build the move list ourselves and do
not vendor lichess `ui`. This reading is not legal advice.

## Out of scope (deferred)

- Persisting reviews / attempt history to the DB.
- Resuming play from a replayed position.
- Auth and per-user Glicko ratings (unchanged from MVP).
