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
    # The landing page changes every day (daily puzzle, counts), so its
    # lastmod is honest. The legal pages have no stored modification time, and
    # an invented lastmod is worse than none.
    entries = [
      {url(conn, ~p"/"), Date.utc_today()},
      {url(conn, ~p"/privacy"), nil},
      {url(conn, ~p"/terms-conditions"), nil},
      {url(conn, ~p"/mentions-legales"), nil}
    ]

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, render_sitemap(entries))
  end

  defp render_sitemap(entries) do
    urls =
      Enum.map_join(entries, fn {loc, lastmod} ->
        "  <url><loc>#{escape(loc)}</loc>#{lastmod_entry(lastmod)}</url>\n"
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{urls}</urlset>
    """
  end

  defp lastmod_entry(nil), do: ""
  defp lastmod_entry(%Date{} = date), do: "<lastmod>#{Date.to_iso8601(date)}</lastmod>"

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
