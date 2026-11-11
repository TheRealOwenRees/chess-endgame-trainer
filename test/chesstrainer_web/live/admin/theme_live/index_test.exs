defmodule ChesstrainerWeb.Admin.ThemeLive.IndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  setup :register_and_log_in_admin

  test "lists themes with their usage count", %{conn: conn} do
    used_theme = theme_fixture(%{name: "Lucena"})
    unused_theme = theme_fixture(%{name: "Philidor"})
    endgame = endgame_fixture()
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [used_theme])

    {:ok, view, _html} = live(conn, ~p"/admin/themes")

    assert has_element?(view, "#theme-#{used_theme.id}")
    assert has_element?(view, "#theme-usage-#{used_theme.id}", "1 endgame")
    assert has_element?(view, "#theme-usage-#{unused_theme.id}", "0 endgames")
  end

  test "filters by name and category", %{conn: conn} do
    theme_fixture(%{name: "Lucena", category: :endgame})
    theme_fixture(%{name: "Philidor", category: :endgame})
    theme_fixture(%{name: "Pin", category: :tactic})

    {:ok, view, _html} = live(conn, ~p"/admin/themes")

    view |> form("#theme-admin-filter-form", %{search: "Luc"}) |> render_change()

    assert has_element?(view, "td", "Lucena")
    refute has_element?(view, "td", "Philidor")
    refute has_element?(view, "td", "Pin")

    view |> form("#theme-admin-filter-form", %{search: "", category: "tactic"}) |> render_change()

    assert has_element?(view, "td", "Pin")
    refute has_element?(view, "td", "Lucena")
  end

  test "shows an empty state that explains what themes do", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/themes")

    assert html =~ "No themes yet"
    assert html =~ "Themes power endgame filtering"
  end

  test "deleting a theme detaches it from endgames and keeps the endgame", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})
    endgame = endgame_fixture()
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [theme])

    {:ok, view, html} = live(conn, ~p"/admin/themes")

    assert html =~ "Used by 1 endgame"
    assert html =~ "The endgames will be kept"

    view |> element("#theme-#{theme.id} a", "Delete") |> render_click()

    assert_raise Ecto.NoResultsError, fn -> Themes.get_theme!(theme.id) end

    assert Endgames.get_endgame!(endgame.id)

    endgame = Endgames.get_endgame!(endgame.id) |> Repo.preload(:themes)
    assert endgame.themes == []
  end
end
