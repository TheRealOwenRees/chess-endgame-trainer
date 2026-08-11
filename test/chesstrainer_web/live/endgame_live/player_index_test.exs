defmodule ChesstrainerWeb.EndgameLive.PlayerIndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures

  test "lists endgames with a play link per row", %{conn: conn} do
    endgame = endgame_fixture()
    other = endgame_fixture()

    {:ok, _view, html} = live(conn, ~p"/endgames")

    assert html =~ "Endgames"
    assert html =~ endgame.key
    assert html =~ other.key
    assert html =~ ~p"/endgames/#{endgame}/play"
    assert html =~ ~p"/endgames/#{other}/play"
  end

  test "navigating to a play page renders the board", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

    assert has_element?(view, "#endgame-board")
    assert has_element?(view, ~s{a[href="/endgames"]})
  end
end
