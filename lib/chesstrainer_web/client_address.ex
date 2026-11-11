defmodule ChesstrainerWeb.ClientAddress do
  @moduledoc """
  Resolves the client's IP address from either a controller connection or a
  LiveView socket.

  `X-Forwarded-For` is only read when
  `Chesstrainer.GuestLimits.trust_forwarded_for?/0` is enabled. In that case the
  rightmost entry is used, because that is the value our own proxy appended.
  Invalid or missing headers fall back to the peer address.
  """

  alias Chesstrainer.GuestLimits

  @typedoc "An IPv4/IPv6 address, or `nil` when no peer data is available."
  @type address :: :inet.ip_address() | nil

  @doc "Returns the client address for a controller connection."
  @spec from_conn(Plug.Conn.t()) :: address()
  def from_conn(conn) do
    if GuestLimits.trust_forwarded_for?() do
      conn
      |> Plug.Conn.get_req_header("x-forwarded-for")
      |> parse_forwarded_header()
      |> fallback(conn.remote_ip)
    else
      conn.remote_ip
    end
  end

  @doc "Returns the client address for a connected LiveView socket."
  @spec from_socket(Phoenix.LiveView.Socket.t()) :: address()
  def from_socket(socket) do
    if GuestLimits.trust_forwarded_for?() do
      socket
      |> Phoenix.LiveView.get_connect_info(:x_headers)
      |> parse_x_headers()
      |> fallback(peer_address(socket))
    else
      peer_address(socket)
    end
  end

  defp peer_address(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: address} -> address
      _ -> nil
    end
  end

  defp parse_forwarded_header([value | _]) when is_binary(value), do: parse_address(value)
  defp parse_forwarded_header(_headers), do: nil

  defp parse_x_headers(headers) when is_list(headers) do
    case List.keyfind(headers, "x-forwarded-for", 0) do
      {_, value} when is_binary(value) -> parse_address(value)
      _ -> nil
    end
  end

  defp parse_x_headers(_headers), do: nil

  # The rightmost entry is the one our own proxy appended.
  defp parse_address(value) do
    value
    |> String.split(",")
    |> List.last()
    |> to_string()
    |> String.trim()
    |> String.to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, address} -> address
      {:error, _} -> nil
    end
  end

  defp fallback(nil, fallback), do: fallback
  defp fallback(address, _fallback), do: address
end
