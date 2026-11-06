defmodule ChesstrainerWeb.RobotsControllerTest do
  use ChesstrainerWeb.ConnCase, async: true

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
  end
end
