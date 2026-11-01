# Client-authoritative move legality; server grades via tablebase

Moves are validated by chess.js on the client (which also renders the board);
the server never applies moves and trusts the client's FEN, only grading the
move against the tablebase. We chose this over server-side validation with Chex
because Chex's move-legality logic is immature, and the app is single-user with
no auth, so client tampering is not a threat. Revisit once the Chex fork is
fixed.
