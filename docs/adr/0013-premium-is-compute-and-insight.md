# Premium sells compute and insight; the free tier keeps the whole play surface

_Status: accepted._

Free play is complete and uncapped: every endgame, every mode at its base
level, every live grade. Premium sells what costs money to produce — on-demand
analysis of an attempt or an imported game — plus the advanced practice that
hangs off it. Nothing a player can learn from is behind the paywall; only what
the player is told about it.

## Why not volume, content or ads

- **Volume caps punish the people most likely to pay.** They also have no
  natural threshold: any daily number is arbitrary, and a user who is improving
  hits it hardest.
- **Content gates already leaked.** Puzzle Search was premium-only in the nav
  but open on its route, so a free user reached it by URL. That gate has since
  been removed: browsing is discovery of content the free tier already owns,
  not analysis. Gating a category of knowledge creates that mess; gating depth
  does not.
- **Ads were closed (#75).** A niche trainer's impressions earn pennies against
  the consent surface the app has been careful to keep small (cookieless,
  no tracking of signed-in pages) and against the positioning that refuses to be
  a generic tactics site.
- **The paywall should sit where the marginal cost is.** Play is local and
  free; analysis costs a remote probe per position. Charging for the part that
  costs money is what keeps the free tier honestly unlimited as usage grows.

## What analysis runs on

DTM is not on disk: local Syzygy answers WDL and DTZ only. The Lichess
tablebase returns `dtm` and `precise_dtz` for any position up to seven pieces.
So distance-to-mate feedback exists, but only over the wire — and the app
already carries a 429 cooldown because that wire is fragile.

Analysis therefore never runs in the play loop. It is requested, queued,
probed against the cache first, and persisted as an artefact on the attempt or
imported game. Repeat views cost nothing; the first view is bounded and
rate-limited. Imported games are judged exactly only where exactness holds —
from the first position with seven pieces or fewer onward. Engine lines, where
shown, are display labelled engine-best; they never grade.

## The free tier's promise

A free player is never left stuck. They always receive the grade, and on a
losing move, the move that was required. Premium explains *why* that move was
the move. "You are wrong, pay to find out why" is the one shape this gate must
never take.

## Scope is bucketed, not closed

Every idea stays alive with a condition for entering:

- **Spine** — engine corridors, blindfold, on-demand analysis, imported games.
  The test for membership: does it make the tablebase do something a free
  tactics site cannot?
- **Enablers** — folded into the spine rather than scheduled separately:
  per-session data, varied opponent defence, unrated sessions.
- **Cheap wins** — allowed when they are about a day: collection URLs,
  lessons that double as premium explanation content.
- **New modalities** — only after the first paid cohort: spaced repetition,
  tactics at volume, the line drill over tactics.
- **Polish** — on complaint: board themes, replacing the board library.
- **Ops** — on trigger, as in ADR-0012.

## Billing

Plans stay admin-set until the premium layer ships; there is nothing to sell
before it exists. When billing lands it goes through a merchant of record
rather than Stripe directly, because selling subscriptions to EU consumers
means VAT and invoicing that a one-person operation should not own.

## Consequences

- Attempts and imported games gain analysis artefacts produced by background
  work; the play loop stays offline-capable and fast.
- `plan` gains meaning without gaining a usage meter, so no play path reads it.
- #82 must be rewritten: the DTM rows are buildable, but from the remote
  backend on demand, not from local tables per move.
- Rate limiting becomes a product concern — an analysis queue — not only an
  availability one.
- The last content gate is gone: the browse link is shown to every signed-in
  user, themed sessions are open at `/train/:theme_slug`, and the play page's
  back link follows the session rather than the plan.
