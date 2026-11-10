defmodule ChesstrainerWeb.PageController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Accounts
  alias Chesstrainer.Attempts
  alias Chesstrainer.Branding
  alias Chesstrainer.DailyPuzzles
  alias Chesstrainer.Endgames

  @description "Short, focused endgame puzzles against tablebase-perfect defence. " <>
                 "Learn to see the winning move and make the endgame your strongest phase."

  def home(conn, _params) do
    if prelaunch?() do
      render_coming_soon(conn)
    else
      endgames = Endgames.curated_endgames()

      conn
      |> assign(:js_entry, ~p"/assets/js/marketing.js")
      |> assign(:page_title, Branding.home_title())
      |> assign(:title_suffix, "")
      |> assign(:meta_description, @description)
      |> assign(:canonical_url, current_url(conn))
      |> assign(:mailing_list_enabled, mailing_list_enabled?())
      |> render(:home,
        endgames: endgames,
        active_endgame: DailyPuzzles.today(),
        puzzle_count: Endgames.count_endgames(),
        user_count: Attempts.count_users_with_attempts(),
        logged_in_count: Accounts.count_logged_in_users(),
        today: Date.utc_today()
      )
    end
  end

  def privacy(conn, _params) do
    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, Branding.title("Privacy Policy"))
    |> assign(:title_suffix, "")
    |> assign(
      :meta_description,
      "How #{Branding.name()} collects, uses, and protects your personal data."
    )
    |> assign(:canonical_url, current_url(conn))
    |> render(:privacy)
  end

  def terms_conditions(conn, _params) do
    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, Branding.title("Terms & Conditions"))
    |> assign(:title_suffix, "")
    |> assign(:meta_description, "The terms that apply when you use #{Branding.name()}.")
    |> assign(:canonical_url, current_url(conn))
    |> render(:terms_conditions)
  end

  def mentions_legales(conn, _params) do
    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, Branding.title("Mentions légales"))
    |> assign(:title_suffix, "")
    |> assign(
      :meta_description,
      "Éditeur, hébergeur et informations légales de #{Branding.name()}."
    )
    |> assign(:canonical_url, current_url(conn))
    |> render(:mentions_legales)
  end

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, Branding.title("Page not found"))
    |> assign(:title_suffix, "")
    |> assign(:noindex, true)
    |> render(:not_found)
  end

  defp render_coming_soon(conn) do
    conn
    |> assign(:js_entry, ~p"/assets/js/marketing.js")
    |> assign(:page_title, Branding.home_title())
    |> assign(:title_suffix, "")
    |> assign(:meta_description, @description)
    |> assign(:canonical_url, current_url(conn))
    |> assign(:noindex, true)
    |> assign(:mailing_list_enabled, mailing_list_enabled?())
    |> render(:coming_soon)
  end

  defp prelaunch?, do: Application.get_env(:chesstrainer, :prelaunch, false)

  defp mailing_list_enabled? do
    Application.get_env(:chesstrainer, :mailing_list_enabled, true)
  end
end
