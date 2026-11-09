defmodule ChesstrainerWeb.HealthControllerTest do
  use ChesstrainerWeb.ConnCase, async: false

  describe "GET /health" do
    test "returns ok with all four fields", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = json_response(conn, 200)

      assert body["status"] == "ok"
      assert body["db"] == "ok"
      assert body["tablebase"] == "local"
      assert body["process"] == "ok"
      assert get_resp_header(conn, "x-robots-tag") == ["noindex"]
    end

    test "returns degraded when local tablebases are not configured", %{conn: conn} do
      previous = Application.get_env(:chesstrainer, :tablebase_path)
      on_exit(fn -> restore_env(:tablebase_path, previous) end)
      Application.delete_env(:chesstrainer, :tablebase_path)

      conn = get(conn, ~p"/health")
      body = json_response(conn, 200)

      assert body["status"] == "degraded"
      assert body["db"] == "ok"
      assert body["tablebase"] == "not_configured"
      assert body["process"] == "ok"
    end

    test "returns degraded when local tablebases are misconfigured", %{conn: conn} do
      previous = Application.get_env(:chesstrainer, :tablebase_path)
      on_exit(fn -> restore_env(:tablebase_path, previous) end)
      Application.put_env(:chesstrainer, :tablebase_path, "/definitely/not/a/tablebase")

      conn = get(conn, ~p"/health")
      body = json_response(conn, 200)

      assert body["status"] == "degraded"
      assert body["db"] == "ok"
      assert body["tablebase"] == "fallback"
      assert body["process"] == "ok"
    end

    test "returns 503 when the database is down", %{conn: conn} do
      previous = Application.get_env(:chesstrainer, :health_database_check)
      on_exit(fn -> restore_env(:health_database_check, previous) end)
      Application.put_env(:chesstrainer, :health_database_check, fn -> false end)

      conn = get(conn, ~p"/health")
      body = json_response(conn, 503)

      assert body["status"] == "down"
      assert body["db"] == "down"
      assert body["tablebase"] == "local"
      assert body["process"] == "ok"
      assert get_resp_header(conn, "x-robots-tag") == ["noindex"]
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
