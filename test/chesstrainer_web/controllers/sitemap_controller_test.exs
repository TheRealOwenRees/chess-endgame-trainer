defmodule ChesstrainerWeb.SitemapControllerTest do
  use ChesstrainerWeb.ConnCase, async: true

  alias ChesstrainerWeb.Endpoint

  describe "GET /sitemap.xml" do
    test "lists only the public marketing pages", %{conn: conn} do
      body = conn |> get(~p"/sitemap.xml") |> response(200)
      base_url = Endpoint.url()

      assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert body =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
      assert body =~ "<loc>#{base_url}/</loc>"
      assert body =~ "<loc>#{base_url}/privacy</loc>"
      assert body =~ "<loc>#{base_url}/terms-conditions</loc>"
      assert length(:binary.matches(body, "<url>")) == 3
    end

    test "is served as XML", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")

      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/xml"
    end
  end
end
