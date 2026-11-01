# MVP: endgame trainer play loop

Goal: a user picks an endgame and plays it against tablebase-optimal defence,
with every move graded against the lichess tablebase, end-to-end.

## Definition of done

- On `/endgames/:id/play`, the seeded endgames (KR v K, KPPP v KPP) load and are
  playable.
- The user plays `endgame.color`; a legal move is graded (optimal / winning /
  losing) against the tablebase; the opponent auto-replies with optimal defence.
- A **losing move** fails the puzzle immediately; **checkmate or a winning
  promotion** solves it.
- Draw endgames are playable: the user holds the draw (solves on chess.js
  `isDraw()`), or fails on a losing move.
- Tablebase unavailability (429/network) blocks the session with a clear message.
- `times_attempted` / `times_solved` increment on finish.

## Decisions (see GLOSSARY.md, docs/adr/)

- Strict trainer; losing move fails. Optimal vs. winning-but-slower are two
  feedback tiers; only losing moves fail.
- Client (chess.js) is authoritative for legality; server grades via tablebase
  (ADR-0002). Tablebase via lichess API (ADR-0001).
- Server holds attempt state in `assigns`; the client is the only engine.
- Grading rule: a move passes iff its category ∈ {loss, syzygy-loss, maybe-loss}
  (opponent still lost); `cursed-win`/`blessed-loss` normalise to draw.
- Cutoff: solve on checkmate or a winning promotion.
- LFU cache with weekly halving sweep.

## Work breakdown

### 0. Prerequisite bug fixes
- `Chesstrainer.Endgames.Tablebase.new/1`: return `{:ok, tablebase}` on a cache
  hit (fix the `{:cache, _}` return + `@spec`); unwrap the tuple in
  `Chesstrainer.Game.game_from_fen/2`.
- `Chesstrainer.Endgames.Tablebase.Parser`: normalise the full category
  vocabulary to `:win | :draw | :loss | :unknown`
  (`win/syzygy-win/maybe-win → :win`; `draw/cursed-win/blessed-loss → :draw`;
  `loss/syzygy-loss/maybe-loss → :loss`).
- `assets/js/hooks/chessBoard.js`: add `promotion` (and `prev_fen`) to the
  `endgame_move_played` payload for unambiguous UCI matching.

### 1. LFU cache rewrite
- `Chesstrainer.Cache`: store `{key, value, freq, last_access}`; on `put`, if
  over `@max_size`, evict lowest frequency (LRU tie-break).
- `Chesstrainer.Cache.Evict`: replace timestamp-based eviction with frequency.
- Add a weekly sweep that halves every entry's frequency
  (`Chesstrainer.Cache` `handle_info` timer, alongside the existing backup).
- `Chesstrainer.Cache.Persist`: the DETS tuple format changes; drop old backups
  (tablebase data is re-fetchable).

### 2. Server attempt state + grading (`EndgameLive.Play`)
- `assigns`: `fen` (grading reference), `status` (`:playing | :solved | :failed
  | :blocked`), `move_list`, `last_grade`.
- `handle_event("endgame_move_played", %{from, to, san, prev_fen, fen_after,
  promotion})`:
  1. grade the move against `prev_fen`'s tablebase (match UCI; pass/fail);
  2. on fail → `status: :failed`, reveal the missed optimal move(s);
  3. on pass → pick the opponent reply (`moves[0]`) from `fen_after`'s
     tablebase, push it to the client, update `fen`;
  4. detect solve (checkmate / winning promotion) and draw (for draw endgames).
- Block: when `Tablebase.new` returns `{:cooldown, _}` or `{:error, _}`,
  set `status: :blocked` and surface a message.

### 3. Client hook (`assets/js/hooks/chessBoard.js`)
- Send `prev_fen` + `fen_after` + `promotion` on each move.
- Apply the opponent reply (from the server) via chess.js and animate it.
- Report draw/mate (chess.js `isDraw()` / `isCheckmate()`) for terminal
  detection.

### 4. Feedback UI (`EndgameLive.Play` + components)
- Two-tier grade display (green "Best" vs. amber "Winning, but suboptimal"),
  losing-move failure with the missed move, solved/failed banner, reset/retry.

### 5. Counters
- Increment `times_attempted` on start; `times_solved` on solve (via
  `Chesstrainer.Endgames`).

## Out of scope (deferred)

- Auth / user accounts: #3
- Glicko rating for users and endgames (puzzle ELO): #4
- Draw via cursed-win 50-move defences; material-based cutoffs; per-endgame
  `win_condition` field.
