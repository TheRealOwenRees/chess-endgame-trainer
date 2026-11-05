defmodule ChesstrainerWeb.PageController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Endgames

  def home(conn, _params) do
    endgames = Endgames.curated_endgames()

    render(conn, :home,
      endgames: endgames,
      active_endgame: List.first(endgames),
      puzzle_count: Endgames.count_endgames()
    )
  end
end
