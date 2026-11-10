defmodule ChesstrainerWeb.Plugs.PutRequestId do
  @moduledoc """
  Copies `Plug.RequestId`'s request id into the session.

  LiveView processes handle later events after the original HTTP request has
  finished. Keeping the id in the session lets `UserAuth.mount_current_scope/2`
  put it into `Logger.metadata/1`, so LiveView logs remain correlatable with the
  request that mounted them.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case conn.assigns[:request_id] do
      nil -> conn
      request_id -> put_session(conn, :request_id, request_id)
    end
  end
end
