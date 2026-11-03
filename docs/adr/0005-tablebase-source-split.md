# Answer five-or-fewer-piece positions from local Syzygy, keep six and seven on Lichess, and cache only the API path

_Status: accepted. Supersedes ADR-0001's "all lookups remote" assumption._

Relying entirely on the Lichess tablebase API put network latency and rate
limits (and a cooldown on 429) in front of every lookup. Hosting everything is
not viable either: the 3-4-5-piece Syzygy set is about 939 MB, six pieces about
150 GB, seven pieces about 18 TB, and eight or more pieces are outside every
tablebase. We route by piece count instead: five or fewer are probed locally
from Syzygy WDL+DTZ files, six and seven go to Lichess, and eight or more are
rejected without a lookup. A local failure — missing or partial files, probe
error — falls back to Lichess, so play only blocks when both sources are
unavailable.

Only the Lichess path is cached. Local probes read from the OS page cache and
are cheap, so an application cache would spend memory on answers we can
regenerate. Cache entries are keyed by position rather than the full FEN: the
result depends only on board, side to move, castling and en-passant, so
clock-only differences are the same position, and the 50-move rule is already
encoded in the WDL/DTZ values rather than the running halfmove clock.

The cost is a native build: the local prober is an MIT-licensed C library
vendored behind a Rust NIF, so a release build needs the Rust toolchain, and
each host points `TABLEBASE_PATH` at its own copy of the files. In exchange the
common (≤5-piece) case is answered without the network or rate limits, while
the enormous 6-7-piece sets stay off our infrastructure.
