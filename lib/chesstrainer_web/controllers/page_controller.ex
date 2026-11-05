defmodule ChesstrainerWeb.PageController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.DailyPuzzles
  alias Chesstrainer.Endgames

  @description "Short, focused endgame puzzles against tablebase-perfect defence. " <>
                 "Learn to see the winning move and make the endgame your strongest phase."

  def home(conn, _params) do
    endgames = Endgames.curated_endgames()

    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, "Lucid Chess — Endgame Trainer")
    |> assign(:title_suffix, "")
    |> assign(:meta_description, @description)
    |> assign(:canonical_url, current_url(conn))
    |> render(:home,
      endgames: endgames,
      active_endgame: DailyPuzzles.today(),
      puzzle_count: Endgames.count_endgames()
    )
  end
end
