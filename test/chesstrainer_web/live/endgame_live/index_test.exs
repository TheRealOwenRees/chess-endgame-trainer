defmodule ChesstrainerWeb.EndgameLive.IndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames

  setup :register_and_log_in_admin

  test "groups endgames by Key with a count", %{conn: conn} do
    endgame_fixture()
    endgame_fixture()

    {:ok, view, html} = live(conn, ~p"/admin/endgames")

    assert html =~ "max-w-7xl"
    assert has_element?(view, "#key-group-K-v-K")
    assert has_element?(view, "#key-group-K-v-K .badge", "2")
  end

  test "trims the table to the key columns", %{conn: conn} do
    endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/endgames")
    view |> element("#key-group-K-v-K button") |> render_click()

    for label <- ~w(Key Color Result Themes Rating) do
      assert has_element?(view, "th", label)
    end

    for label <- ~w(Fen Message Notes Attempted Solved) do
      refute has_element?(view, "th", label)
    end
  end

  test "lazy-loads a group's endgames when expanded", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})
    endgame = endgame_fixture()
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [theme])

    {:ok, view, html} = live(conn, ~p"/admin/endgames")

    # collapsed: the endgame row (and its themes) are not rendered yet
    refute html =~ ~p"/endgames/#{endgame}/play"
    refute html =~ "Lucena"

    view |> element("#key-group-K-v-K button") |> render_click()

    html = render(view)
    assert html =~ ~p"/endgames/#{endgame}/play"
    assert html =~ "Lucena"
  end

  test "filters by theme", %{conn: conn} do
    lucena = theme_fixture(%{name: "Lucena"})
    philidor = theme_fixture(%{name: "Philidor"})

    kr = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    kq = endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")
    {:ok, _} = Endgames.update_endgame(kr, %{}, [lucena])
    {:ok, _} = Endgames.update_endgame(kq, %{}, [philidor])

    {:ok, view, _html} = live(conn, ~p"/admin/endgames")

    view |> form("#theme-filter-form", %{theme_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    assert has_element?(view, "#key-group-KR-v-K")
    refute has_element?(view, "#key-group-KQ-v-K")
  end

  test "filters by Key", %{conn: conn} do
    endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")

    {:ok, view, _html} = live(conn, ~p"/admin/endgames")

    view |> form("#key-filter-form", %{key: "KQ v K"}) |> render_change()

    assert has_element?(view, "#key-group-KQ-v-K")
    refute has_element?(view, "#key-group-KR-v-K")
  end
end
