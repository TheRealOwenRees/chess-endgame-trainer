defmodule ChesstrainerWeb.SitemapController do
  @moduledoc """
  Generates `/sitemap.xml` for the indexable public pages.

  Endgame play pages are deliberately left out: there are tens of thousands of
  them and they render the same interactive surface with only the position
  differing, so listing them all would be index bloat. Revisit that if public
  browse pages (by Key or theme) exist and are worth ranking.
  """

  use ChesstrainerWeb, :controller

  def index(conn, _params) do
    urls = [
      url(conn, ~p"/"),
      url(conn, ~p"/privacy"),
      url(conn, ~p"/terms-conditions"),
      url(conn, ~p"/mentions-legales")
    ]

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, render_sitemap(urls))
  end

  defp render_sitemap(urls) do
    entries = Enum.map_join(urls, &"  <url><loc>#{escape(&1)}</loc></url>\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}</urlset>
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
