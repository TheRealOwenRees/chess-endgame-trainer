defmodule ChesstrainerWeb.RobotsControllerTest do
  use ChesstrainerWeb.ConnCase, async: false

  alias ChesstrainerWeb.Endpoint

  describe "GET /robots.txt" do
    test "allows crawlers and points at the sitemap", %{conn: conn} do
      body = conn |> get(~p"/robots.txt") |> response(200)

      assert body =~ "User-agent: *"
      assert body =~ "Allow: /"
      assert body =~ "Sitemap: #{Endpoint.url()}/sitemap.xml"
    end

    test "is served as plain text", %{conn: conn} do
      conn = get(conn, ~p"/robots.txt")

      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "text/plain"
    end

    test "disallows crawlers while prelaunch is on", %{conn: conn} do
      previous = Application.get_env(:chesstrainer, :prelaunch)
      on_exit(fn -> restore_env(:prelaunch, previous) end)
      Application.put_env(:chesstrainer, :prelaunch, true)

      body = conn |> get(~p"/robots.txt") |> response(200)

      assert body =~ "User-agent: *"
      assert body =~ "Disallow: /"
      refute body =~ "Allow: /"
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
