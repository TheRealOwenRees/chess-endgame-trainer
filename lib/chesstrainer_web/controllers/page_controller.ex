defmodule ChesstrainerWeb.PageController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Endgames

  def home(conn, _params) do
    endgames = Endgames.curated_endgames()

    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> render(:home,
      endgames: endgames,
      active_endgame: List.first(endgames),
      puzzle_count: Endgames.count_endgames()
    )
  end
end
