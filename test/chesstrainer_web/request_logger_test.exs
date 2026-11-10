defmodule ChesstrainerWeb.RequestLoggerTest do
  use ChesstrainerWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Plug.Conn

  alias ChesstrainerWeb.RequestLogger

  setup do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)
    :ok
  end

  describe "handle_event/4" do
    test "logs one access line with method, path, status, duration and request id" do
      conn = access_conn("GET", "/endgames", 200, "request-1")

      log =
        capture_log([level: :info], fn ->
          RequestLogger.handle_event(
            [:phoenix, :endpoint, :stop],
            %{duration: 12_500_000},
            %{conn: conn},
            :ok
          )
        end)

      assert log =~ "GET /endgames 200 in 12.5ms"
      assert log =~ "request_id=request-1"
    end

    test "redacts token-like path segments" do
      token = "SFMyNTY." <> String.duplicate("a", 43)
      conn = access_conn("GET", "/users/reset-password/#{token}", 200, "request-1")

      log =
        capture_log([level: :info], fn ->
          RequestLogger.handle_event(
            [:phoenix, :endpoint, :stop],
            %{duration: 1_000_000},
            %{conn: conn},
            :ok
          )
        end)

      assert log =~ "GET /users/reset-password/[REDACTED] 200 in 1.0ms"
      refute log =~ token
    end

    test "never logs the query string" do
      conn =
        :get
        |> build_conn("/endgames?email=user@example.com&secret=abc")
        |> assign(:request_id, "request-1")
        |> put_status(200)

      log =
        capture_log([level: :info], fn ->
          RequestLogger.handle_event(
            [:phoenix, :endpoint, :stop],
            %{duration: 1_000_000},
            %{conn: conn},
            :ok
          )
        end)

      assert log =~ "GET /endgames 200 in 1.0ms"
      refute log =~ "user@example.com"
      refute log =~ "secret=abc"
    end
  end

  describe "endpoint integration" do
    test "emits exactly one access line for a request", %{conn: conn} do
      log = capture_log([level: :info], fn -> get(conn, ~p"/health") end)

      assert length(Regex.scan(~r/GET \/health 200 in [\d.]+ms/, log)) == 1
      assert log =~ "request_id="
    end

    test "emits an access line for a LiveView initial request", %{conn: conn} do
      log = capture_log([level: :info], fn -> get(conn, ~p"/users/log-in") end)

      assert length(Regex.scan(~r/GET \/users\/log-in 200 in [\d.]+ms/, log)) == 1
      assert log =~ "request_id="
    end
  end

  defp access_conn(method, path, status, request_id) do
    method
    |> build_conn(path)
    |> assign(:request_id, request_id)
    |> put_status(status)
  end
end
