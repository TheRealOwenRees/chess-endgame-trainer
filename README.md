# Chesstrainer

To start your Phoenix server:

* Run `docker compose up -d` to run the development database
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Local tablebases (optional)

Positions with five or fewer pieces are answered locally from Syzygy
tablebases when `TABLEBASE_PATH` points at a directory of `.rtbw`/`.rtbz`
files. When it is unset the trainer falls back to the Lichess API.

`TABLEBASE_PATH` lets each environment point at its own copy — it differs on a
dev machine and a VPS:

```sh
# Fetch the complete 3/4/5-piece WDL+DTZ set (~939 MB) once per host.
mix tablebase.fetch --path /path/to/syzygy/3-4-5
mix tablebase.check --path /path/to/syzygy/3-4-5

# Dev
TABLEBASE_PATH=/path/to/syzygy/3-4-5 mix phx.server

# Production
TABLEBASE_PATH=/data/syzygy/3-4-5 bin/chesstrainer start
```

On boot the app logs whether the local tablebases loaded and the largest piece
count they cover, so a wrong path shows up immediately.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
