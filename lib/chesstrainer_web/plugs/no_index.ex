defmodule ChesstrainerWeb.Plugs.NoIndex do
  @moduledoc """
  Tells crawlers not to index the response.

  Uses the `X-Robots-Tag` header rather than a `<meta name="robots">` tag: it
  survives redirects and authentication failures, and covers LiveView pages
  without every template having to assign `:noindex`.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_resp_header(conn, "x-robots-tag", "noindex, nofollow")
  end
end
