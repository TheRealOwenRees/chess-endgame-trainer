# Eight-or-more-piece endgames are trained from engine-sourced corridors that hand off to the tablebase at seven

_Status: accepted. Extends ADR-0005: the ≤7-piece source split stands; this adds a source for 8+._

Syzygy stops at seven pieces and there is no tablebase for eight or more. To
train such endgames without pretending to a completeness they lack, each 8+
endgame is backed by a **corridor**: one or two winning lines, generated offline
with a chess engine (Stockfish), that stay clearly winning at every step. The
corridor is stored as solved positions keyed by position key and served by a new
tablebase backend, so the play loop and grading are unchanged.

The corridor ends at the first capture that brings the board to seven pieces or
fewer. From that position the existing router answers from Syzygy (≤5, local) or
Lichess (6–7), so the tail of every puzzle is tablebase-optimal. Generation
verifies the handoff: it probes the ≤7 position and asserts it is still a win for
the winning side. A promotion does not end the corridor, because it does not
reduce the piece count; only a capture does.

A second line is stored only when both lines are clearly winning — the engine's
evaluation stays above the winning threshold throughout. A line that dips is
discarded rather than shipped as a dubious alternative.

## Grading

Inside the corridor grading is binary: a move on a stored line passes, a move
off the lines fails. The stored move list is deliberately incomplete, so it
cannot support the "any winning move passes" rule the tablebase enables; the
user must find the technique the corridor encodes. Once the position reaches
seven pieces, grading returns to the existing optimal/winning/losing model.

## Why not the alternatives

- **Engine at runtime.** Removes the offline step but adds per-move latency, a
  rate limit if it is a remote service, and non-determinism in what counts as
  "winning". The corridor is deterministic and free at play time.
- **Hand-authored book.** The same shape without an engine to generate it:
  fragile, narrow, and prone to grading a move as losing only because nobody
  wrote it down.
- **Solving the whole 8+ region.** Infeasible. The corridor trades completeness
  for a short, verified path to a position the tablebase can finish.

## Consequences

- Endgames gain an `oracle` (`:tablebase` or `:corridor`). The changeset admits
  8+ FENs only for corridor endgames.
- A corridor-position store (keyed by position key) and a tree backend join the
  existing Fathom/Lichess backends. Eight-plus positions without a corridor are
  still rejected.
- Generation depends on a Stockfish binary at build/curation time, not at
  runtime.
- The corridor is engine-best, not proven-optimal. Honest wording ("engine-best
  defence") is required in player-facing copy, and GLOSSARY's *optimal move* and
  *winning move* need a corridor-aware distinction.
- An off-corridor legal move fails the attempt; this is a deliberate departure
  from tablebase grading and must be reflected in the play surface.
