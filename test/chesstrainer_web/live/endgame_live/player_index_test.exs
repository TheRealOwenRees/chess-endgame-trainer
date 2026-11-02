defmodule ChesstrainerWeb.EndgameLive.PlayerIndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames

  test "groups endgames by Key and shows themes on expand", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})
    endgame = endgame_fixture()
    other = endgame_fixture()
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [theme])

    {:ok, view, html} = live(conn, ~p"/endgames")

    assert html =~ "Endgames"
    assert has_element?(view, "#key-group-K-v-K")
    refute html =~ "Lucena"

    view |> element("#key-group-K-v-K button") |> render_click()

    html = render(view)
    assert html =~ ~p"/endgames/#{endgame}/play"
    assert html =~ ~p"/endgames/#{other}/play"
    assert html =~ "Lucena"
  end

  test "filters by theme", %{conn: conn} do
    lucena = theme_fixture(%{name: "Lucena"})
    philidor = theme_fixture(%{name: "Philidor"})

    kr = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    kq = endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")
    {:ok, _} = Endgames.update_endgame(kr, %{}, [lucena])
    {:ok, _} = Endgames.update_endgame(kq, %{}, [philidor])

    {:ok, view, _html} = live(conn, ~p"/endgames")

    view |> form("#theme-filter-form", %{theme_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    assert has_element?(view, "#key-group-KR-v-K")
    refute has_element?(view, "#key-group-KQ-v-K")
  end

  test "navigating to a play page renders the board", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

    assert has_element?(view, "#endgame-board")
    assert has_element?(view, ~s{a[href="/endgames"]})
  end
end
