defmodule ChesstrainerWeb.HealthController do
  @moduledoc """
  Lightweight health check used by deploys and uptime monitors.
  """

  use ChesstrainerWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
