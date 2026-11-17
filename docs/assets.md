# Asset bundle sizes

What the browser downloads, measured rather than guessed. Numbers below are
from the last production build (`mix assets.deploy`, minified and digested) and
were read with `mix assets.sizes`.

Re-measure after any asset change:

```sh
mix assets.deploy
mix assets.sizes
```

`mix assets.sizes` prints raw, gzip and brotli sizes for every built JS and CSS
file. Brotli shows as `-` when the `brotli` CLI is not installed.

## Current bundles

| File | Raw | Gzip |
| --- | ---: | ---: |
| `assets/js/app.js` (LiveView entry) | 219.7 KB | 69.2 KB |
| `assets/js/marketing.js` (controller pages) | 4.8 KB | 1.9 KB |
| `assets/css/app.css` | 94.2 KB | 17.3 KB |

Cached font files, served only when used: DM Sans variable 62.5 KB, DM Serif
Display 24.5 KB, DM Serif Display italic 24.4 KB, DM Sans italic 14.6 KB
(woff2, already compressed).

## What is in each bundle

`app.js` is a single entry loaded by every LiveView page. It contains:

| Part | Raw | Gzip |
| --- | ---: | ---: |
| `phoenix`, `phoenix_live_view`, `phoenix_html` | — | ~30 KB |
| `chessground` (`dist/chessground.min.js`) | 30.0 KB | 11.0 KB |
| `chess.js` (`dist/esm/chess.js`) | 107.1 KB | 23.9 KB |
| `topbar` | 4.3 KB | 1.5 KB |
| `nav`, `analytics`, hooks | ~8 KB | ~3 KB |

The library figures are the packages' own builds; esbuild's minification and
tree shaking mean the bundle total is smaller than the naive sum.

`marketing.js` is deliberately tiny: `phoenix_html`, the nav toggle and the
cookieless analytics loader. It has no LiveView, socket, hooks or topbar.
Controller pages (landing page, legal pages, 404) load it instead of `app.js`.

`app.css` is one Tailwind build for the whole site, including the three
chessground stylesheets (`chessground.base.css` 3.3 KB, `chessground.brown.css`
2.8 KB, `chessground.cburnett.css` 11.5 KB raw, ~4.7 KB gzipped together).

## Findings

1. **Board code is about half of `app.js` and most pages do not use it.**
   chessground and chess.js are ~35 KB of the 69 KB gzip payload. They are
   needed only by pages that render `ChessBoard`: guest training, play, review.
   Profile, settings, the endgame list and every admin screen pay for them and
   never instantiate a board.
2. **The marketing/public split is already right.** Public pages do not load
   the LiveView runtime at all.
3. **Board CSS is in the global stylesheet.** ~4.7 KB gzipped of chess piece
   and board styling reaches every page, including the landing page.
4. **Stale digested bundles accumulate.** `priv/static/assets` currently holds
   three generations of `app-*.js` and `app-*.css`. They are not linked but do
   bloat the release. `mix phx.digest.clean --age 0` (or deploying from a clean
   build) removes them.

## Recommendation (not applied)

Split the board libraries out of the LiveView entry:

- Load `chessground` and `chess.js` with a dynamic `import()` inside
  `assets/js/hooks/chessBoard.js` and build with esbuild `--splitting
  --format=esm`. Pages without a board then never fetch the chunk; board pages
  fetch it once, in parallel with the hook mounting.
- Expected result: `app.js` drops from ~69 KB to ~35 KB gzip on most
  authenticated pages, with a separate ~35 KB board chunk fetched only where
  needed.
- Move the chessground stylesheets into the board chunk's CSS (or a second CSS
  entry loaded only on board pages) to take ~4.7 KB off every page.
- Set a budget in CI once the split lands: `app.js` ≤ 40 KB gzip, board chunk
  ≤ 40 KB gzip, `marketing.js` ≤ 2 KB gzip, `app.css` ≤ 20 KB gzip.

No build configuration was changed as part of this measurement.
