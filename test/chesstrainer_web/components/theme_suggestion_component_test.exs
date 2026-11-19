defmodule ChesstrainerWeb.ThemeSuggestionComponentTest.HostLive do
  @moduledoc false
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias ChesstrainerWeb.PlayComponents

  @impl true
  def mount(_params, session, socket) do
    endgame = Endgames.get_endgame!(session["endgame_id"])

    current_scope =
      case session["user_id"] do
        nil -> nil
        user_id -> Scope.for_user(Repo.get!(User, user_id))
      end

    {:ok,
     assign(socket,
       endgame: endgame,
       current_scope: current_scope,
       status: String.to_existing_atom(session["status"] || "solved")
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <PlayComponents.play_surface
      endgame={@endgame}
      status={@status}
      plies={[]}
      line={[]}
      reviewing={false}
      review_index={0}
      awaiting_reply={false}
      current_scope={@current_scope}
    />
    """
  end
end

defmodule ChesstrainerWeb.ThemeSuggestionComponentTest do
  use ChesstrainerWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  test "guests do not see the themes section", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = render_play(conn, endgame, nil)

    refute has_element?(view, "#theme-teaching")
  end

  test "a finished puzzle shows its themes to a signed-in player", %{conn: conn} do
    endgame = endgame_fixture()
    user = user_fixture()
    theme = theme_fixture(%{name: "Lucena"})
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [theme])

    {:ok, view, html} = render_play(conn, endgame, user)

    assert html =~ "What this puzzle teaches"
    assert has_element?(view, "#theme-teaching", "Lucena")
  end

  test "suggests an existing technique theme without linking it", %{conn: conn} do
    endgame = endgame_fixture()
    user = attempted_user(endgame)
    linked = theme_fixture(%{name: "Lucena"})
    suggestible = theme_fixture(%{name: "Philidor"})
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [linked])

    {:ok, view, _html} = render_play(conn, endgame, user)

    view |> form("#theme-suggestion-search-form", %{query: "Phil"}) |> render_change()
    view |> element("#suggest-#{suggestible.id}") |> render_click()

    assert render(view) =~ "Suggestion sent for review."
    assert Themes.pending_suggestion_count(endgame.id) == 1

    assert [%{theme_id: theme_id, status: :pending}] =
             Repo.all(
               from s in Chesstrainer.Themes.ThemeSuggestion,
                 where: s.endgame_id == ^endgame.id,
                 select: %{theme_id: s.theme_id, status: s.status}
             )

    assert theme_id == suggestible.id
    assert link_count(endgame.id) == 1
  end

  test "proposes a new technique theme name", %{conn: conn} do
    endgame = endgame_fixture()
    user = attempted_user(endgame)

    {:ok, view, _html} = render_play(conn, endgame, user)

    view
    |> form("#theme-suggestion-proposal-form", %{name: "Opposition"})
    |> render_submit()

    assert render(view) =~ "Suggestion sent for review."

    assert [suggestion] = Themes.list_suggestions_for_user(user.id)
    assert suggestion.proposed_name == "Opposition"
    assert suggestion.status == :pending
  end

  test "requires a recorded attempt before accepting a suggestion", %{conn: conn} do
    endgame = endgame_fixture()
    user = user_fixture()
    theme = theme_fixture(%{name: "Philidor"})

    {:ok, view, _html} = render_play(conn, endgame, user)

    view |> form("#theme-suggestion-search-form", %{query: "Phil"}) |> render_change()
    view |> element("#suggest-#{theme.id}") |> render_click()

    assert render(view) =~ "Finish the puzzle before suggesting a theme."
    assert Themes.pending_suggestion_count(endgame.id) == 0
  end

  test "withdraws a pending suggestion", %{conn: conn} do
    endgame = endgame_fixture()
    user = attempted_user(endgame)
    scope = Scope.for_user(user)

    {:ok, suggestion} = Themes.suggest_theme(scope, endgame, %{proposed_name: "Triangulation"})

    {:ok, view, _html} = render_play(conn, endgame, user)

    view |> element("#withdraw-#{suggestion.id}") |> render_click()

    assert render(view) =~ "Suggestion withdrawn."
    assert Themes.pending_suggestion_count(endgame.id) == 0
  end

  defp render_play(conn, endgame, user) do
    live_isolated(conn, ChesstrainerWeb.ThemeSuggestionComponentTest.HostLive,
      session: %{
        "endgame_id" => endgame.id,
        "user_id" => user && user.id
      }
    )
  end

  defp attempted_user(endgame) do
    user = user_fixture()
    {:ok, _attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)
    user
  end

  defp link_count(endgame_id) do
    Repo.one(
      from l in "endgames_themes",
        where: l.endgame_id == type(^endgame_id, :binary_id),
        select: count(l.theme_id)
    )
  end
end
