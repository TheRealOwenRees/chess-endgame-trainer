defmodule ChesstrainerWeb.RobotsController do
  @moduledoc """
  Serves `/robots.txt` with a sitemap URL that follows the deployment's host.

  Built at runtime from the endpoint configuration rather than checked in as a
  static file, so the sitemap stays correct across environments.
  """

  use ChesstrainerWeb, :controller

  def index(conn, _params) do
    body = """
    User-agent: *
    Allow: /

    Sitemap: #{url(conn, ~p"/sitemap.xml")}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end
end
