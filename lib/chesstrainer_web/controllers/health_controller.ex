defmodule ChesstrainerWeb.HealthController do
  @moduledoc """
  JSON health check used by deploys and uptime monitors.
  """

  use ChesstrainerWeb, :controller

  def index(conn, _params) do
    health = Chesstrainer.Health.status()
    status = if health.status == "down", do: :service_unavailable, else: :ok

    conn
    |> put_resp_header("x-robots-tag", "noindex")
    |> put_status(status)
    |> json(health)
  end
end
