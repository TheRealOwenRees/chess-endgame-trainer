# Cache only the graded tablebase outcome, at ~100k entries with sampled eviction and daily best-effort backups

The cached value keeps only what the trainer reads: the position's category,
checkmate flag and moves (each with category, `dtz`, `san` and `uci`), plus
`dtm`/`dtc` as a small, deliberate hedge for a future "mate in N" or
distance-to-conversion feature. The rest of the API response — `dtw`, precise
DTZ, per-move terminal and variant flags, material flags — is dropped: it is
never read, and slimming each entry from ~10 KB to ~4 KB keeps the working set
in memory. Cursed-win and blessed-loss are normalised to a draw at parse time,
so the variant and `dtw` fields mean nothing here. The cost is that a richer
trainer would need a cache shape (and DETS format) change and a refill;
`dtm`/`dtc` keep the most likely such feature cheap.

The cache holds 100k entries by default and is configurable. At ~4 KB per entry
that is roughly 400 MB of BEAM memory per node — accepted because the cache is a
warm, per-node optimization rather than the source of truth, and the cap is
configurable for smaller deployments. That is large enough that the recurring
working set rarely evicts, and at capacity eviction samples ~64 entries and
drops the least-frequently-used of those rather than scanning the whole table
for the exact victim: a cache that re-fetches on a miss only needs *a* cold
entry, and the O(n) scan per put was what stopped the cache scaling past ~100k.
The weekly frequency-halving sweep stays, because it is time-based aging rather
than victim selection. The cache is warm state — the
API is the source of truth — so a daily backup at 03:00 UTC, written off the
cache process to a temporary file and atomically renamed, is the right
durability level: a crash can lose up to a day of cache, costing rate-limited
re-fetches rather than data, and a torn write can never replace a good backup.
