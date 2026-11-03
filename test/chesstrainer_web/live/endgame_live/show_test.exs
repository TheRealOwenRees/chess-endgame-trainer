defmodule ChesstrainerWeb.EndgameLive.ShowTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures

  setup :register_and_log_in_admin

  test "shows the public code alongside the database id", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/#{endgame.id}")

    assert has_element?(view, "li.list-row", "Public code")
    assert has_element?(view, "li.list-row", endgame.public_code)
    assert has_element?(view, "h1", endgame.id)
  end

  test "links to the player surface by public code", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/#{endgame.id}")

    assert has_element?(view, ~s{a[href="/endgames/#{endgame.public_code}/play"]})
  end
end
