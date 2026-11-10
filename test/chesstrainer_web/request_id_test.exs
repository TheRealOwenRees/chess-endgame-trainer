defmodule ChesstrainerWeb.RequestIdTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias ChesstrainerWeb.Plugs.PutRequestId
  alias ChesstrainerWeb.UserAuth

  setup do
    on_exit(fn -> Logger.metadata(request_id: nil) end)
  end

  test "PutRequestId copies the request id into the session" do
    conn =
      :get
      |> Phoenix.ConnTest.build_conn("/")
      |> Phoenix.ConnTest.init_test_session(%{})
      |> assign(:request_id, "request-1")
      |> PutRequestId.call([])

    assert get_session(conn, :request_id) == "request-1"
  end

  test "PutRequestId leaves the session alone without a request id" do
    conn =
      :get
      |> Phoenix.ConnTest.build_conn("/")
      |> Phoenix.ConnTest.init_test_session(%{})
      |> PutRequestId.call([])

    assert get_session(conn, :request_id) == nil
  end

  test "mounting a LiveView puts the session's request id into logger metadata" do
    socket = %Phoenix.LiveView.Socket{}

    assert {:cont, _socket} =
             UserAuth.on_mount(
               :mount_current_scope,
               %{},
               %{"request_id" => "request-2", "user_token" => nil},
               socket
             )

    assert Logger.metadata()[:request_id] == "request-2"
  end
end
