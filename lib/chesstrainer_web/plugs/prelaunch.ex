defmodule ChesstrainerWeb.Plugs.Prelaunch do
  @moduledoc """
  Redirects every non-public route to the home page while the app is gated.

  The allowlist is deliberately small: legal pages, the mailing list, auth
  entry points, admin, crawler files, health, and the static/LiveView plumbing.
  Everything else redirects to `/` with `X-Robots-Tag: noindex, nofollow`.

  Set `PRELAUNCH=true` to enable the gate.
  """

  import Plug.Conn

  @allowed_exact ~w(
    /
    /privacy
    /terms-conditions
    /mentions-legales
    /health
    /robots.txt
    /sitemap.xml
    /favicon.ico
  )

  @allowed_prefixes ~w(
    /mailing-list
    /users/log-out
    /users/confirm
    /users/reset-password
    /users/settings
    /admin
    /live
    /assets
    /fonts
    /images
    /dev
  )

  def init(opts), do: opts

  def call(conn, _opts) do
    if enabled?() and not allowed?(conn.request_path) do
      conn
      |> put_resp_header("x-robots-tag", "noindex, nofollow")
      |> Phoenix.Controller.redirect(to: "/")
      |> halt()
    else
      conn
    end
  end

  defp enabled?, do: Application.get_env(:chesstrainer, :prelaunch, false)

  defp allowed?(path) do
    path in @allowed_exact or
      Enum.any?(@allowed_prefixes, &String.starts_with?(path, &1))
  end
end
