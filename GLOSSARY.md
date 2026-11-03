# Chesstrainer

An endgame trainer: the user plays a stored endgame position against
tablebase-optimal defence and is graded on every move.

## Core model

**Endgame**:
A stored chess position (FEN) plus metadata — side to move, result, rating,
tags — that can be played as a puzzle.
_Avoid_: Position, puzzle

**Puzzle**:
A playable challenge derived from an endgame: play the winning (or drawing)
side correctly against tablebase-optimal defence.
_Avoid_: Endgame (the stored record), exercise

**Attempt**:
One playthrough of a puzzle by a user, ending solved or failed.
_Avoid_: Run, session, game

**Theme**:
A label describing an endgame's technique or goal, such as "mate in 2", "Lucena" or
"opposition"; an endgame can carry several.
_Avoid_: Tag, label, category

**Key**:
The canonical material signature of an endgame's starting position — which
pieces each side has, written strongest side first and colour-agnostic
(e.g. "KQ v KR"). Used to group and search endgames by material.
_Avoid_: Material signature, hash

## Play

**Winning side**:
The side that can force a win from the position; the side the user plays in
win-type endgames.

**Drawing side**:
In draw endgames, the side that must hold the draw; the side the user plays.
_Avoid_: Defender

**Optimal move**:
The tablebase's best move for the side to move (sharpest win / hardest defence).

**Winning move**:
A move that keeps the win (the opponent is still lost). Passes.
_Avoid_: Good move, accurate move

**Losing move**:
A move that throws away the result (the position becomes drawn or lost).
Fails the puzzle.
_Avoid_: Blunder, mistake

**Conversion**:
The decisive zeroing move — a promotion — that ends a conversion-type puzzle.

**Cutoff**:
The terminal condition short of mate at which a puzzle counts as solved:
promotion (still winning) for conversion puzzles, mate otherwise.

## Infrastructure

**Tablebase**:
A database of precomputed optimal outcomes for every position with at most
seven pieces. Positions with five or fewer pieces are answered from local
Syzygy files; six and seven piece positions come from the lichess API. The
trainer keeps only the outcome data it grades on — enough to tell a winning
move from a losing one — and caches API answers only; local answers are cheap
enough to refetch.

**Probe**:
A single lookup of one position in the tablebase, returning its result and its
legal moves. A probe is answered locally or by the API.

**Position key**:
The identity of a tablebase position — board, side to move, castling and
en-passant — excluding the move clocks. FENs that differ only in their clocks
share a position key.
_Avoid_: Full FEN

**Cooldown**:
Rate-limit state entered after a 429 from the lichess API, during which the
trainer blocks play for positions that need the API (six or seven pieces).
Local positions are unaffected.

**Cache sweep**:
The periodic halving of LFU cache frequencies (weekly) that lets rarely-used
entries age out.
