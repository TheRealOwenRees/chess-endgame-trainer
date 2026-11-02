# Canonical, colour-agnostic material Key for endgames

An endgame's `key` is derived from its FEN rather than typed by hand, as the
material signature of the start position: each side's pieces, strongest side
first by material value (`Q=9, R=5, B=3, N=3, P=1`) and colour-agnostic, so
`KQ v KR` is the same key whichever colour has the queen. Bishop square colour
is not encoded. We chose this over a white-vs-black ordering or a free-text key
so endgames with the same material group together regardless of colour, and so
the key can never drift from the position; side-to-move and outcome stay in the
`color` and `result` fields.
