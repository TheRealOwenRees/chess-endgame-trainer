defmodule ChesstrainerWeb.ClientAddressTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Chesstrainer.GuestLimits
  alias ChesstrainerWeb.ClientAddress

  @peer {10, 0, 0, 1}
  @forwarded {203, 0, 113, 9}

  setup do
    previous = Application.get_env(:chesstrainer, GuestLimits, [])
    on_exit(fn -> Application.put_env(:chesstrainer, GuestLimits, previous) end)
    :ok
  end

  test "ignores X-Forwarded-For when trust is off" do
    trust_forwarded_for(false)

    conn =
      conn(:post, "/users/log-in")
      |> Map.put(:remote_ip, @peer)
      |> Map.put(:req_headers, [{"x-forwarded-for", "203.0.113.9"}])

    assert ClientAddress.from_conn(conn) == @peer
  end

  test "honours the rightmost X-Forwarded-For entry when trust is on" do
    trust_forwarded_for(true)

    conn =
      conn(:post, "/users/log-in")
      |> Map.put(:remote_ip, @peer)
      |> Map.put(:req_headers, [{"x-forwarded-for", "198.51.100.2, 203.0.113.9"}])

    assert ClientAddress.from_conn(conn) == @forwarded
  end

  test "falls back to the peer address for an invalid forwarded header" do
    trust_forwarded_for(true)

    conn =
      conn(:post, "/users/log-in")
      |> Map.put(:remote_ip, @peer)
      |> Map.put(:req_headers, [{"x-forwarded-for", "not-an-address"}])

    assert ClientAddress.from_conn(conn) == @peer
  end

  test "ignores socket X-Forwarded-For when trust is off" do
    trust_forwarded_for(false)

    assert ClientAddress.from_socket(socket()) == @peer
  end

  test "honours socket X-Forwarded-For when trust is on" do
    trust_forwarded_for(true)

    assert ClientAddress.from_socket(socket()) == @forwarded
  end

  defp socket do
    %Phoenix.LiveView.Socket{
      private: %{
        connect_info: %{
          peer_data: %{address: @peer},
          x_headers: [{"x-forwarded-for", "203.0.113.9"}]
        }
      }
    }
  end

  defp trust_forwarded_for(enabled?) do
    config = Application.get_env(:chesstrainer, GuestLimits, [])

    Application.put_env(
      :chesstrainer,
      GuestLimits,
      Keyword.put(config, :trust_forwarded_for, enabled?)
    )
  end
end
