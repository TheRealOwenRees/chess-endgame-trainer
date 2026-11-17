defmodule ChesstrainerWeb.Admin.ThemeLive.FormTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Themes

  setup :register_and_log_in_admin

  test "creates a theme", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/themes/new")

    view
    |> form("#theme-form", theme: %{name: "  Lucena  ", category: "endgame"})
    |> render_submit()

    assert_redirect(view, ~p"/admin/themes")

    assert [%{name: "Lucena", slug: "lucena", kind: :technique, category: :endgame}] =
             Themes.search("Lucena", "endgame")
  end

  test "creates a theme with a kind and description", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/themes/new")

    view
    |> form("#theme-form",
      theme: %{
        name: "Rook endgame",
        kind: "material",
        category: "endgame",
        description: "Positions where a rook and pawn face a rook."
      }
    )
    |> render_submit()

    assert_redirect(view, ~p"/admin/themes")

    assert [theme] = Themes.search("Rook endgame", "endgame")
    assert theme.slug == "rook-endgame"
    assert theme.kind == :material
    assert theme.description == "Positions where a rook and pawn face a rook."
  end

  test "renames and recategorises a theme", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena", category: :endgame})

    {:ok, view, _html} = live(conn, ~p"/admin/themes/#{theme.id}/edit")

    view
    |> form("#theme-form", theme: %{name: "Lucena", category: "opening"})
    |> render_submit()

    assert_redirect(view, ~p"/admin/themes")

    updated = Themes.get_theme!(theme.id)
    assert updated.name == "Lucena"
    assert updated.category == :opening
  end

  test "shows the existing duplicate-name validation error", %{conn: conn} do
    theme_fixture(%{name: "Lucena", category: :endgame})

    {:ok, view, _html} = live(conn, ~p"/admin/themes/new")

    html =
      view
      |> form("#theme-form", theme: %{name: "lucena", category: "endgame"})
      |> render_submit()

    assert html =~ "already exists"
    assert length(Themes.list_themes()) == 1
  end

  test "validates a blank name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/themes/new")

    html =
      view
      |> form("#theme-form", theme: %{name: "", category: "endgame"})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
  end

  test "shows the admin sub-navigation", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/themes/new")

    assert html =~ ~p"/admin/endgames"
    assert html =~ ~p"/admin/themes"
    assert html =~ ~p"/admin/users"
  end
end
