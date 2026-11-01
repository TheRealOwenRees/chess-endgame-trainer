defmodule ChesstrainerWeb.EndgameLive.IndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.TagsFixtures

  alias Chesstrainer.Endgames

  test "lists an endgame's themes", %{conn: conn} do
    tag = tag_fixture(%{name: "Lucena"})
    endgame = endgame_fixture()
    {:ok, _endgame} = Endgames.update_endgame(endgame, %{}, [tag])

    {:ok, _view, html} = live(conn, ~p"/admin/endgames")

    assert html =~ "Lucena"
  end
end
