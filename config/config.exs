# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :chesstrainer, :scopes,
  user: [
    default: true,
    module: Chesstrainer.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: Chesstrainer.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :chesstrainer,
  ecto_repos: [Chesstrainer.Repo],
  generators: [timestamp_type: :utc_datetime]

# Glicko rating system.
#
# `system_constant` is the volatility constraint passed through to the Glicko
# package. `window_days` is the minimum gap before replaying the same
# user/endgame pair may change either rating again. `rd_inflation_c` widens a
# rating deviation by sqrt(c^2 * days) while that side is inactive, capped at
# the Glicko maximum (350).
config :chesstrainer, :ratings,
  system_constant: 0.8,
  window_days: 7,
  rd_inflation_c: 10.0

# Public codes of the endgames pinned to the landing-page puzzle grid, in
# display order. When empty (or short) the grid is topped up with a date-seeded
# selection from the database, so it stays stable for a given day.
config :chesstrainer, :curated_endgame_codes, []

# Configure the endpoint
config :chesstrainer, ChesstrainerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ChesstrainerWeb.ErrorHTML, json: ChesstrainerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Chesstrainer.PubSub,
  live_view: [signing_salt: "u0HD4N5a"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :chesstrainer, Chesstrainer.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  chesstrainer: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  chesstrainer: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure the tablebase cache: maximum entries and the UTC time of the daily
# backup. Both can be overridden with environment variables at runtime.
config :chesstrainer, Chesstrainer.Cache,
  max_size: 100_000,
  backup_time: {3, 0}

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
