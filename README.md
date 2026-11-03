# Chesstrainer

To start your Phoenix server:

* Run `docker compose up -d` to run the development database
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Local tablebases (optional)

Positions with five or fewer pieces are answered locally from Syzygy tablebases
when `TABLEBASE_PATH` points at a directory of `.rtbw`/`.rtbz` files; otherwise
lookups fall back to Lichess.

```sh
mix tablebase.fetch --path /path/to/syzygy/3-4-5   # once per host (~939 MB)
export TABLEBASE_PATH=/path/to/syzygy/3-4-5        # set per environment
```

See [docs/tablebases.md](docs/tablebases.md) for the full reference — dev vs
VPS paths, `mix tablebase.check`, and boot logging.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
