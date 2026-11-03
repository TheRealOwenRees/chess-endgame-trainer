# Tablebases

The trainer answers endgame positions from two sources, chosen by piece count
(kings included):

| Pieces | Source |
| ------ | ------ |
| 5 or fewer | Local Syzygy files, probed through the Fathom NIF |
| 6–7 | Lichess tablebase API, cached |
| 8 or more | Not covered — rejected before any lookup |

If a local probe fails (files missing, partial set, probe error), the lookup
falls back to Lichess, so play only blocks when both sources are unavailable.

## `TABLEBASE_PATH`

The local backend reads its directory from the **`TABLEBASE_PATH`** environment
variable at boot (`config/runtime.exs`). It is environment-specific: a dev
machine and a VPS will point at different copies.

```sh
# Development
export TABLEBASE_PATH=/home/you/Downloads/tablebase
mix phx.server

# Production (release)
TABLEBASE_PATH=/data/syzygy/3-4-5 bin/chesstrainer start
```

The value must reach the process. A bare `TABLEBASE_PATH=...` line in bash
only sets a shell variable and is **not** exported to `mix` or the release —
use `export`, or prefix the command. For a release, systemd unit or container,
set it in that service's environment, not an interactive shell.

When `TABLEBASE_PATH` is unset the local backend is disabled and every lookup
falls back to Lichess (subject to its rate limits).

## Installing the files

Fathom expects the `.rtbw` (WDL) and `.rtbz` (DTZ) files **flat** in the
directory; both sets are required (WDL for the result, DTZ for optimal-move
ranking and the 50-move-rule categories).

```sh
mix tablebase.fetch --path /path/to/syzygy/3-4-5   # ~939 MB, resumable
mix tablebase.fetch --path /path/to/syzygy/3-4-5 --dry-run
mix tablebase.check --path /path/to/syzygy/3-4-5   # verifies it loads
```

`mix tablebase.check` exits non-zero when the path is unset, contains no files,
or Fathom cannot initialise it.

## Boot logging

On startup the app logs one of:

- `local Syzygy tablebases ready at <path> (largest=5)`
- `local Syzygy tablebases disabled (TABLEBASE_PATH unset)`
- `local Syzygy tablebases at <path> contain no files`
- `local Syzygy tablebases failed: <reason>`

## Deployment note

The Fathom NIF is compiled to `priv/native/fathom_nif.so` and ships inside the
release. Whichever machine *builds* the release therefore needs the Rust
toolchain (and crates.io access); the runtime host only needs the release
artefact plus the tablebase files.

See `docs/adr/0001-tablebase-via-lichess-api.md` (predates local probing) and
`docs/adr/0004-tablebase-cache-shape-and-scaling.md`.
