# Spine: what order to build in

Goal: turn the live free trainer into something worth paying for, without
starting the expensive content work first.

The spine is the four things that compound on the tablebase — blindfold,
analysis, imported games, corridors — and the order below is about dependency
and revenue, not enthusiasm. ADR-0013 records why the paywall sits where it
does; this document records what comes first.

## The order

| # | Work | Size | Why here |
|---|---|---|---|
| 1 | #200 Blindfold presentation mode | days | No dependencies. The only cheap test of the positioning, and its "the hidden board leaks nothing" work is a prerequisite for every later blindfold mode. |
| 2 | #203 Analysis artefact and background queue | 1–2 weeks | The keystone: #204, #205 and #207 all hang off it. Nothing is sellable before it exists. |
| 3 | #206 PGN ingest and endgame-tail extraction | ~1 week | Independent of #203, so it runs in parallel. First half of the flagship. |
| 4 | #204 Distance and 50-move feedback · #205 Structural detectors | 1–2 weeks | The first thing a player would actually pay for: "you extended the path to mate by 3", "that was stalemate". |
| 5 | #207 Exact scan · #208 Weakness report | 2–3 weeks | The flagship. No free tactics site can copy "here are the rook endgames you keep losing". |
| 6 | #92–98 + #99 Corridors | 4–6 weeks | Content breadth and the stored lines #202 needs. Expensive, and not on the path to revenue. |
| 7 | #201 Blindfold progression · #202 Line drill | 1–2 weeks each | The second paid layer, once the first exists and the base mode has proven itself. |

Billing stays last: there is nothing to charge for until #204–#208 exist.

## Why this order, and what changed

An earlier order put corridors second, because they were the only way to add
content. Two things moved since:

- **The library is 13k puzzles.** Breadth is not the constraint; the paid layer
  is.
- **Imported games became the flagship**, and #207 reuses the analysis artefact
  from #203. Corridors are therefore not on the critical path to the first paid
  feature — they unblock 8+ content and #202, nothing else.

## Parallel start

#200, #203 and #206 touch almost disjoint code — the board hook and play
surface; a new schema plus background work; a new context plus an import
screen — and all three are `ready-for-agent`.

```text
week 1   #200            #203                      #206
week 2   —               #204                      #206 finish
week 3   —               #205                      #207
week 4   —               —                         #208
week 5   stop, measure, then choose corridors / #201 / billing
```

The calendar is illustrative, not a commitment. The order is the commitment.

## The measurement gate

After #200 ships, look at one number: **do players retry a blindfold puzzle?**

- Yes → blindfold is a real second pillar; #201 is worth building later.
- No → the positioning's second half is weaker than assumed, and the analysis
  and corridor work matter more, not less.

Do not build #201 before this gate is passed. Progression is a paywall on
something unproven.

## Dependencies worth remembering

- #202 needs #95 (stored corridor lines).
- #207 needs #203 (shared analysis artefact).
- #208 needs #207 and a session identity on attempts (folded in from #73).
- #99 cannot finish before #92 lands: its first criterion is that ADR-0011
  matches shipped behaviour.

## Out of scope

- Corridors before the paid layer.
- Blindfold progression before the measurement gate.
- Billing before there is a feature to sell.
- Everything in the *deferred* buckets: #209, #217, #218, and the polish issues.

## Where the work is tracked

- Milestone **Spine 90 days** — the tickets above, in the order they appear.
- Epics: #199 blindfold · #82 analysis · #81 imported games · #101 corridors.
- Product scope and the paywall: ADR-0013.
