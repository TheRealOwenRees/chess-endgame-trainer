defmodule ChesstrainerWeb.PageController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Attempts
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
      puzzle_count: Endgames.count_endgames(),
      user_count: Attempts.count_users_with_attempts(),
      today: Date.utc_today()
    )
  end

  def privacy(conn, _params) do
    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, "Privacy Policy — Lucid Chess")
    |> assign(:title_suffix, "")
    |> assign(
      :meta_description,
      "How Lucid Chess collects, uses, and protects your personal data."
    )
    |> assign(:canonical_url, current_url(conn))
    |> render(:privacy)
  end

  def terms_conditions(conn, _params) do
    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, "Terms & Conditions — Lucid Chess")
    |> assign(:title_suffix, "")
    |> assign(:meta_description, "The terms that apply when you use Lucid Chess.")
    |> assign(:canonical_url, current_url(conn))
    |> render(:terms_conditions)
  end
end
