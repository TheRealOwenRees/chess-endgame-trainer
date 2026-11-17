defmodule ChesstrainerWeb.SitemapController do
  @moduledoc """
  Generates `/sitemap.xml` for the indexable public pages.

  Endgame play pages are deliberately left out: there are tens of thousands of
  them and they render the same interactive surface with only the position
  differing, so listing them all would be index bloat. Revisit that if public
  browse pages (by Key or theme) exist and are worth ranking.

  No `<lastmod>` is emitted: none of these pages has a stored modification time,
  and an invented date (such as "today" on every request) teaches crawlers to
  distrust the sitemap.
  """

  use ChesstrainerWeb, :controller

  def index(conn, _params) do
    entries = [
      url(conn, ~p"/"),
      url(conn, ~p"/privacy"),
      url(conn, ~p"/terms-conditions"),
      url(conn, ~p"/mentions-legales")
    ]

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, render_sitemap(entries))
  end

  defp render_sitemap(entries) do
    urls =
      Enum.map_join(entries, fn loc ->
        "  <url><loc>#{escape(loc)}</loc></url>\n"
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{urls}</urlset>
    """
  end

  # Templates escape automatically; this response is built as a plain string,
  # so XML-significant characters must be escaped here.
  defp escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
