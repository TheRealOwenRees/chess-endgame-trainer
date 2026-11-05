# The landing page is a server-rendered dead view

The marketing home page is a controller-rendered page (a "dead view") rather
than a LiveView. It shows a static board preview of the first curated endgame
and links to `/endgames/<public code>/play`; the puzzle is not playable on the
home page. Curated puzzle cards are ordinary links, and the puzzle count in the
learning strip is read from the database on each request.

LiveView renders its first response on the server too, so the SEO argument is
mostly about certainty: a dead view guarantees crawlers receive a complete
document without a websocket connecting. It also drops the LiveSocket round
trip and live-diff overhead from the page whose job is to be fast and
indexable. The cost is losing the interactive demo: visitors must follow a
link to try a puzzle, which is where attempts are recorded anyway.

## Consequences

- `HomeLive` and `HomeBoardComponent` are removed; all solving happens on
  `/endgames/:public_code/play`.
- The board on the home page is `LandingComponents.board_preview/1` and is
  deliberately inert.
- The "Try today's puzzle", "Begin with the basics", and each puzzle card link
  straight to the first/selected endgame's player URL, using its public code.
- The puzzle count is request-time, not baked at build time, so it cannot go
  stale between deploys.
- If the page feels slow in practice, the next step is a lighter
  marketing-only JS bundle without the LiveSocket — deferred until measured.
