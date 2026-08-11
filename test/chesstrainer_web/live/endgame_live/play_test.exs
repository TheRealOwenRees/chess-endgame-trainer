defmodule ChesstrainerWeb.EndgameLive.PlayTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures

  defp assert_init_board(view, expected_fen, expected_orientation, expected_player_color) do
    %{proxy: {ref, _topic, _}} = view

    assert_receive {^ref, {:push_event, "init_board", payload}}, 100

    assert payload.fen == expected_fen
    assert payload.orientation == expected_orientation
    assert payload.player_color == expected_player_color
  end

  describe "mount" do
    test "renders the chessboard hook div and pushes init_board", %{conn: conn} do
      endgame = endgame_fixture(color: :white)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert has_element?(view, "#endgame-board")
      assert_init_board(view, endgame.fen, "white", "white")
    end

    test "pushes black orientation when the endgame color is black", %{conn: conn} do
      endgame = endgame_fixture(color: :black)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert_init_board(view, endgame.fen, "black", "black")
    end

    test "shows endgame metadata in the header", %{conn: conn} do
      endgame = endgame_fixture(key: "KQ v K", color: :white, result: :win, rating: 1800)

      {:ok, _view, html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert html =~ "KQ v K"
      assert html =~ "white to move"
      assert html =~ "win"
      assert html =~ "1800"
    end

    test "raises when the endgame does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/endgames/00000000-0000-0000-0000-000000000000/play")
      end
    end
  end

  describe "chess_fen_invalid" do
    test "shows a flash when the chessground hook reports an unparseable FEN", %{conn: conn} do
      endgame = endgame_fixture()

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      view
      |> render_hook("chess_fen_invalid", %{
        "fen" => endgame.fen,
        "message" => "Invalid FEN: move number must be a positive integer"
      })

      html = render(view)
      assert html =~ "Endgame FEN is invalid"
      assert html =~ "move number must be a positive integer"
    end
  end

  describe "endgame_move_played" do
    test "appends the SAN move and updates last_san / last_from_to", %{conn: conn} do
      endgame = endgame_fixture()

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      view
      |> render_hook("endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      html = render(view)
      assert html =~ "Qd7+"
      assert html =~ "d1 ➔ d7"
    end
  end

  describe "reset" do
    test "clears move list and re-pushes init_board", %{conn: conn} do
      endgame = endgame_fixture()

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      view
      |> render_hook("endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      assert render(view) =~ "Qd7+"

      view |> element("button", "Reset") |> render_click()

      assert render(view) =~ "No Moves"
      assert_init_board(view, endgame.fen, "white", "white")
    end
  end
end
