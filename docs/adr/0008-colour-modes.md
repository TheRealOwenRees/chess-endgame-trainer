# Colour modes use a branded-inverse palette with role tokens

UI colour mode (`system`, `light`, `dark`) is a per-browser preference stored in
`localStorage["phx:theme"]`; `system` follows `prefers-color-scheme` and updates
live when the OS setting changes. The switch lives in the navbar
(`Layouts.colour_mode_toggle/1`) and the mode is applied before first paint by
the inline script in `root.html.heex`.

Dark mode is a branded inverse of the landing page's paper/ink/mint/coral
palette, not Phoenix's stock slate. The raw swatches are role-overloaded —
`--ink` is both body text and the fill behind white text; `--coral-dark` is both
small text on paper and the hover fill under white text — so `app.css` defines a
role layer (`--color-canvas`, `--color-body`, `--color-coral-control`, …) that
templates and stylesheets use. A colour mode overrides only the roles; light
mode reads them from the raw palette. The roles are exposed as `--color-*`, so
they also generate Tailwind utilities (`bg-canvas`, `text-muted`,
`border-hairline`) for templates that use utilities instead of named classes.

The chessboard is deliberately excluded. Chessground's brown board and cburnett
pieces stay identical in both modes, as does the landing-page preview board.
The board is content: recolouring it would make the same position look
different without helping the player, and the piece SVGs are tuned for the
brown board. Only the furniture around it — frame, time pill, promotion
picker — adapts.

## Consequences

- Adding or changing a colour mode means redefining role values, not hunting
  selectors. Templates and `app.css` never reference the raw swatches.
- The Phoenix semantic tokens (`primary`, `base-*`, `accent`, …) are retuned to
  the brand in both modes, so admin and auth screens do not turn blue in dark
  mode. The missing `warning` and `error` dark values are now defined.
- Content colours (`--color-board-*`, `--color-piece-*`,
  `--color-on-deep-*`) are intentionally identical across modes.
- The admin preview board (`assets/css/_board.css`) was left out of scope; it
  remains light-only until revisited.
- Light-mode WCAG contrast failures are a knowing deferral, tracked in #61. The
  role split means fixing them is a value change, not a refactor.
- The GDPR/ePrivacy position for the `localStorage` preference is tracked in
  #60.
