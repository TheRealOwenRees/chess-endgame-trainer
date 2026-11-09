import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/chesstrainer start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :chesstrainer, ChesstrainerWeb.Endpoint, server: true
end

if prelaunch = System.get_env("PRELAUNCH") do
  config :chesstrainer, :prelaunch, prelaunch in ~w(true 1)
end

if mailing_list_enabled = System.get_env("MAILING_LIST_ENABLED") do
  config :chesstrainer, :mailing_list_enabled, mailing_list_enabled in ~w(true 1)
end

# Local Syzygy tablebases: set TABLEBASE_PATH to the directory holding the
# .rtbw/.rtbz files. When unset, the local backend stays disabled and lookups
# fall back to Lichess.
if tablebase_path = System.get_env("TABLEBASE_PATH") do
  config :chesstrainer, :tablebase_path, tablebase_path
end

# Tablebase cache: size and the UTC time of the daily backup. Environment
# variables win over the defaults in config/config.exs so deployments can tune
# the cache without a rebuild. Invalid values are reported and ignored rather
# than crashing boot with an opaque parse error.
cache_config = Application.get_env(:chesstrainer, Chesstrainer.Cache, [])
default_max_size = Keyword.fetch!(cache_config, :max_size)
default_backup_time = Keyword.fetch!(cache_config, :backup_time)

cache_max_size =
  case System.get_env("TABLEBASE_CACHE_MAX_SIZE") do
    nil ->
      default_max_size

    value ->
      case Integer.parse(value) do
        {size, ""} when size > 0 ->
          size

        _ ->
          IO.warn(
            "ignoring TABLEBASE_CACHE_MAX_SIZE=#{inspect(value)}: " <>
              "expected a positive integer, using #{default_max_size}",
            []
          )

          default_max_size
      end
  end

cache_backup_time =
  case System.get_env("TABLEBASE_BACKUP_TIME") do
    nil ->
      default_backup_time

    value ->
      case Chesstrainer.Cache.BackupSchedule.parse_time(value) do
        {:ok, time} ->
          time

        :error ->
          IO.warn(
            "ignoring TABLEBASE_BACKUP_TIME=#{inspect(value)}: " <>
              "expected HH:MM in UTC, using #{inspect(default_backup_time)}",
            []
          )

          default_backup_time
      end
  end

config :chesstrainer, Chesstrainer.Cache,
  max_size: cache_max_size,
  backup_time: cache_backup_time

# Guest puzzle limit: free puzzles per UTC day for anonymous visitors. The
# visitor is identified by a keyed hash of their address held in memory only.
# Enable TRUST_FORWARDED_FOR only behind a proxy that sets the header.
config :chesstrainer, Chesstrainer.GuestLimits,
  limit: String.to_integer(System.get_env("GUEST_PUZZLE_LIMIT", "5")),
  trust_forwarded_for: System.get_env("TRUST_FORWARDED_FOR") in ~w(true 1)

config :chesstrainer, ChesstrainerWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :chesstrainer, Chesstrainer.Mailer,
    adapter: Swoosh.Adapters.AmazonSES,
    region:
      System.get_env("SES_REGION") ||
        raise("environment variable SES_REGION is missing"),
    access_key:
      System.get_env("SES_ACCESS_KEY_ID") ||
        raise("environment variable SES_ACCESS_KEY_ID is missing"),
    secret:
      System.get_env("SES_SECRET_ACCESS_KEY") ||
        raise("environment variable SES_SECRET_ACCESS_KEY is missing")

  config :chesstrainer, Chesstrainer.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :chesstrainer, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :chesstrainer, ChesstrainerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # The release runs behind Caddy, so bind to loopback and let the proxy
      # handle public traffic.
      ip: {127, 0, 0, 1}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :chesstrainer, ChesstrainerWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :chesstrainer, ChesstrainerWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :chesstrainer, Chesstrainer.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
