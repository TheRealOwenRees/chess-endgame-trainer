defmodule ChesstrainerWeb.StaticCacheTest do
  use ChesstrainerWeb.ConnCase, async: true

  # One year, matching `Plug.Static` in the endpoint when code reloading is off.
  # A missing max-age here lets the CDN fall back to its own short default.
  @one_year "public, max-age=31536000, immutable"

  test "digested build output is cached for a year", %{conn: conn} do
    conn = get(conn, ~p"/assets/css/app.css")

    assert conn.status == 200
    assert get_resp_header(conn, "cache-control") == [@one_year]
  end

  test "stable-name assets are cached for a year", %{conn: conn} do
    for path <- ["/fonts/dm-sans-variable.woff2", "/images/og.png", "/favicon.svg"] do
      conn = get(conn, path)

      assert conn.status == 200
      assert get_resp_header(conn, "cache-control") == [@one_year]
    end
  end
end
