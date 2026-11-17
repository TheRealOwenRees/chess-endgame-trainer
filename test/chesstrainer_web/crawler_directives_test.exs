defmodule ChesstrainerWeb.CrawlerDirectivesTest do
  use ChesstrainerWeb.ConnCase, async: true

  @noindex "noindex, nofollow"

  describe "X-Robots-Tag" do
    test "authenticated routes are noindex even when redirecting to log in", %{conn: conn} do
      conn = get(conn, ~p"/train")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert get_resp_header(conn, "x-robots-tag") == [@noindex]
    end

    test "the branded 404 page is noindex", %{conn: conn} do
      conn = get(conn, "/this-page-does-not-exist")

      assert html_response(conn, 404)
      assert get_resp_header(conn, "x-robots-tag") == [@noindex]
    end

    test "the mailing-list confirmation redirect is noindex", %{conn: conn} do
      conn = get(conn, "/mailing-list/confirm/oops")

      assert redirected_to(conn) == "/#mailing-list"
      assert get_resp_header(conn, "x-robots-tag") == [@noindex]
    end

    test "public pages are not marked noindex", %{conn: conn} do
      for path <- [~p"/", ~p"/privacy", ~p"/terms-conditions", ~p"/mentions-legales"] do
        conn = get(conn, path)
        html = html_response(conn, 200)

        assert get_resp_header(conn, "x-robots-tag") == []
        refute html =~ ~s(name="robots")
        refute html =~ "nofollow"
      end
    end

    test "pages that assign :noindex carry the same policy as the header", %{conn: conn} do
      html = conn |> get("/this-page-does-not-exist") |> html_response(404)

      assert html =~ ~s(<meta name="robots" content="#{@noindex}")
    end
  end
end
