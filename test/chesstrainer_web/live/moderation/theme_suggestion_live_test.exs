defmodule ChesstrainerWeb.Moderation.ThemeSuggestionLiveTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  @path "/moderation/theme-suggestions"

  test "guests are sent to log in" do
    assert redirected_to(get(build_conn(), @path)) == ~p"/users/log-in"
  end

  test "members are sent home" do
    conn = log_in_user(build_conn(), user_with_role(:member))

    assert redirected_to(get(conn, @path)) == ~p"/"
  end

  test "moderators see the queue with proposer and evidence", %{conn: conn} do
    suggestion = pending_suggestion(theme_name: "Lucena")

    {:ok, view, html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    assert has_element?(view, "#queue-count", "1 pending suggestion")
    assert has_element?(view, "#suggestion-#{suggestion.id}")
    assert has_element?(view, "#target-#{suggestion.id}", "Lucena")
    assert html =~ suggestion.author.username
    assert html =~ "1 suggestion"
    assert html =~ "Review suggestions"
  end

  test "admins can review too", %{conn: conn} do
    suggestion = pending_suggestion()

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:admin)), @path)

    assert has_element?(view, "#suggestion-#{suggestion.id}")
  end

  test "approving links the theme as community and clears the item", %{conn: conn} do
    suggestion = pending_suggestion()

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    view |> element("#approve-#{suggestion.id}") |> render_click()

    assert render(view) =~ "Suggestion approved."
    assert has_element?(view, "#queue-count", "0 pending suggestions")
    assert render(view) =~ "Nothing is waiting for review."

    suggestion = Themes.get_suggestion!(suggestion.id)
    assert suggestion.status == :accepted
    assert suggestion.reviewed_at

    assert link_source(suggestion.endgame_id, suggestion.theme_id) == "community"
  end

  test "approving a proposed name creates the theme and links it", %{conn: conn} do
    suggestion = pending_suggestion(proposed_name: "Opposition")

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    view |> element("#approve-#{suggestion.id}") |> render_click()

    suggestion = Themes.get_suggestion!(suggestion.id)
    theme = Repo.get_by!(Chesstrainer.Themes.Theme, name: "Opposition")

    assert suggestion.status == :accepted
    assert link_source(suggestion.endgame_id, theme.id) == "community"
  end

  test "rejecting records a reason without linking", %{conn: conn} do
    suggestion = pending_suggestion()

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    view
    |> form("#reject-#{suggestion.id}", %{note: "Not this position"})
    |> render_submit()

    assert render(view) =~ "Suggestion rejected."

    suggestion = Themes.get_suggestion!(suggestion.id)
    assert suggestion.status == :rejected
    assert suggestion.note == "Not this position"
    assert link_source(suggestion.endgame_id, suggestion.theme_id) == nil
  end

  test "rejecting without a reason shows an error", %{conn: conn} do
    suggestion = pending_suggestion()

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    view |> form("#reject-#{suggestion.id}", %{note: "  "}) |> render_submit()

    assert render(view) =~ "Give a reason before rejecting."
    assert Themes.get_suggestion!(suggestion.id).status == :pending
  end

  test "merging a proposed name into an existing theme", %{conn: conn} do
    suggestion = pending_suggestion(proposed_name: "Opposition")
    target = theme_fixture(%{name: "Philidor"})

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    view
    |> form("#merge-#{suggestion.id}", %{theme_id: target.id})
    |> render_submit()

    assert render(view) =~ "Suggestion merged and approved."

    suggestion = Themes.get_suggestion!(suggestion.id)
    assert suggestion.status == :merged
    assert link_source(suggestion.endgame_id, target.id) == "community"
    refute Repo.get_by(Chesstrainer.Themes.Theme, name: "Opposition")
  end

  test "paginates the queue", %{conn: conn} do
    for _ <- 1..11, do: pending_suggestion()

    {:ok, view, _html} = live(log_in_user(conn, user_with_role(:moderator)), @path)

    assert has_element?(view, "#queue-count", "11 pending suggestions")
    assert view |> render() |> String.split("id=\"suggestion-") |> length() == 11

    view |> element("button", "Next") |> render_click()

    html = render(view)
    assert html =~ "Page 2 of 2"
    assert html |> String.split("id=\"suggestion-") |> length() == 2
  end

  defp pending_suggestion(opts \\ []) do
    endgame = endgame_fixture()
    author = user_fixture()
    {:ok, _attempt} = Attempts.record_attempt(Scope.for_user(author), endgame, :solved)

    attrs =
      case Keyword.get(opts, :proposed_name) do
        nil ->
          theme = theme_fixture(%{name: Keyword.get(opts, :theme_name, unique_theme_name())})
          {%{theme_id: theme.id}, theme}

        name ->
          {%{proposed_name: name}, nil}
      end

    {attrs, theme} = attrs
    {:ok, suggestion} = Themes.suggest_theme(Scope.for_user(author), endgame, attrs)

    %{id: suggestion.id, endgame_id: endgame.id, theme_id: theme && theme.id, author: author}
  end

  defp user_with_role(:member), do: user_fixture()

  defp user_with_role(role) do
    {:ok, user} = Accounts.update_user_role(user_fixture(), role)
    user
  end

  defp link_source(endgame_id, theme_id) do
    Repo.one(
      from l in "endgames_themes",
        where: l.endgame_id == type(^endgame_id, :binary_id) and l.theme_id == ^theme_id,
        select: l.source
    )
  end
end
