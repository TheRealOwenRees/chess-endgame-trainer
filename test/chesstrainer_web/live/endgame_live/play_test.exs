defmodule ChesstrainerWeb.EndgameLive.PlayTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.Ratelimiters

  defp assert_init_board(view, expected_fen, expected_orientation, expected_player_color) do
    %{proxy: {ref, _topic, _}} = view

    assert_receive {^ref, {:push_event, "init_board", payload}}, 100

    assert payload.fen == expected_fen
    assert payload.orientation == expected_orientation
    assert payload.player_color == expected_player_color
  end

  # Seed the tablebase cache so mount never touches the network in tests.
  defp seed_tablebase(fen, opts \\ []) do
    tablebase = %Tablebase{
      category: Keyword.get(opts, :category, :win),
      checkmate: Keyword.get(opts, :checkmate, false),
      moves: Keyword.get(opts, :moves, [])
    }

    TablebaseCache.put(fen, tablebase)
    on_exit(fn -> TablebaseCache.delete(fen) end)
  end

  defp grading_moves do
    [
      %Tablebase.Move{uci: "d1d7", san: "Qd7+", category: :loss, dtz: -1},
      %Tablebase.Move{uci: "d1d5", san: "Qd5", category: :loss, dtz: -9},
      %Tablebase.Move{uci: "d1d4", san: "Qd4", category: :draw, dtz: 0}
    ]
  end

  defp draw_moves do
    [
      %Tablebase.Move{uci: "d1d7", san: "Qd7", category: :draw, dtz: nil},
      %Tablebase.Move{uci: "d1d4", san: "Qd4", category: :win, dtz: nil}
    ]
  end

  defp play_move(view, endgame, from, to, san) do
    render_hook(view, "endgame_move_played", %{
      "from" => from,
      "to" => to,
      "san" => san,
      "prev_fen" => endgame.fen,
      "fen" => endgame.fen,
      "endgame_id" => endgame.id
    })
  end

  describe "mount" do
    test "renders the chessboard hook div and pushes init_board", %{conn: conn} do
      endgame = endgame_fixture(color: :white)
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert has_element?(view, "#endgame-board")
      assert_init_board(view, endgame.fen, "white", "white")
    end

    test "pushes black orientation when the endgame color is black", %{conn: conn} do
      endgame = endgame_fixture(color: :black)
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert_init_board(view, endgame.fen, "black", "black")
    end

    test "shows endgame metadata in the header", %{conn: conn} do
      endgame = endgame_fixture(key: "KQ v K", color: :white, result: :win, rating: 1800)
      seed_tablebase(endgame.fen)

      {:ok, _view, html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert html =~ "KQ v K"
      assert html =~ "White to move"
      assert html =~ "1800"
    end

    test "raises when the endgame does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/endgames/00000000-0000-0000-0000-000000000000/play")
      end
    end
  end

  describe "tablebase availability" do
    test "blocks the attempt when the tablebase is cooling down", %{conn: conn} do
      endgame = endgame_fixture()
      TablebaseCache.delete(endgame.fen)
      Ratelimiters.lichess_add_cooldown()
      on_exit(fn -> Ratelimiters.lichess_reset_cooldown() end)

      {:ok, view, html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert html =~ "Tablebase unavailable"

      play_move(view, endgame, "d1", "d7", "Qd7+")
      assert render(view) =~ "cannot be graded"
    end
  end

  describe "chess_fen_invalid" do
    test "shows a flash when the chessground hook reports an unparseable FEN", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

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
    test "grades the optimal move", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      play_move(view, endgame, "d1", "d7", "Qd7+")
      html = render(view)

      assert html =~ "Optimal move"
      assert html =~ "Qd7+"
    end

    test "grades a winning but slower move as winning", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      play_move(view, endgame, "d1", "d5", "Qd5")

      assert render(view) =~ "Winning — but not the sharpest"
    end

    test "fails a move that throws the win away", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      assert render(view) =~ "Failed"
    end

    test "rejects a move that is out of sequence", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "prev_fen" => "8/8/8/8/8/8/8/8 w - - 0 1",
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      assert render(view) =~ "out of sequence"
    end
  end

  describe "opponent reply" do
    test "plays the opponent's optimal defence and resumes the user's turn", %{conn: conn} do
      endgame = endgame_fixture()
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"
      fen_after_reply = "8/8/8/8/8/8/8/8 w - - 0 1"
      reply = %Tablebase.Move{uci: "e8e7", san: "Ke7", category: :loss, dtz: -3}

      seed_tablebase(endgame.fen, moves: grading_moves())
      seed_tablebase(fen_after, category: :loss, moves: [reply])
      seed_tablebase(fen_after_reply, category: :win, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "prev_fen" => endgame.fen,
        "fen" => fen_after,
        "endgame_id" => endgame.id
      })

      %{proxy: {ref, _topic, _}} = view

      assert_receive {^ref, {:push_event, "opponent_move", payload}}, 100

      assert payload == %{from: "e8", to: "e7", promotion: nil, san: "Ke7"}

      render_hook(view, "opponent_reply_applied", %{"fen" => fen_after_reply})

      assert_receive {^ref, {:push_event, "resume_board", _payload}}, 100
    end

    test "does not reply when the move throws the win away", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      %{proxy: {ref, _topic, _}} = view

      refute_receive {^ref, {:push_event, "opponent_move", _payload}}, 100
      assert render(view) =~ "Failed"
    end
  end

  describe "attempt outcome" do
    test "records an attempt on start", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, _view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert Endgames.get_endgame!(endgame.id).times_attempted == 1
    end

    test "solves on checkmate", %{conn: conn} do
      endgame = endgame_fixture()
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"

      seed_tablebase(endgame.fen, moves: grading_moves())
      seed_tablebase(fen_after, checkmate: true, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "prev_fen" => endgame.fen,
        "fen" => fen_after,
        "endgame_id" => endgame.id
      })

      assert render(view) =~ "Solved!"
      assert Endgames.get_endgame!(endgame.id).times_solved == 1
    end

    test "solves on a promotion that keeps the win", %{conn: conn} do
      endgame = endgame_fixture()
      moves = [%Tablebase.Move{uci: "a7a8q", san: "a8=Q", category: :loss, dtz: -1}]
      seed_tablebase(endgame.fen, moves: moves)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "a7",
        "to" => "a8",
        "san" => "a8=Q",
        "promotion" => "q",
        "prev_fen" => endgame.fen,
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      assert render(view) =~ "Solved!"
      assert Endgames.get_endgame!(endgame.id).times_solved == 1
    end

    test "fails on a losing move and reveals the best move", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      html = render(view)
      assert html =~ "Failed"
      assert html =~ "Qd7+"
      assert Endgames.get_endgame!(endgame.id).times_solved == 0
    end
  end

  describe "draw endgames" do
    test "loads and is playable", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      seed_tablebase(endgame.fen, category: :draw, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      assert has_element?(view, "#endgame-board")
      assert render(view) =~ "Make a move"
    end

    test "passes a move that keeps the draw and replies", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"
      reply = %Tablebase.Move{uci: "e8e7", san: "Ke7", category: :draw, dtz: nil}

      seed_tablebase(endgame.fen, category: :draw, moves: draw_moves())
      seed_tablebase(fen_after, category: :draw, moves: [reply])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7",
        "draw" => false,
        "prev_fen" => endgame.fen,
        "fen" => fen_after,
        "endgame_id" => endgame.id
      })

      %{proxy: {ref, _topic, _}} = view

      assert_receive {^ref, {:push_event, "opponent_move", payload}}, 100
      assert payload == %{from: "e8", to: "e7", promotion: nil, san: "Ke7"}
    end

    test "fails a move that loses the draw", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      seed_tablebase(endgame.fen, category: :draw, moves: draw_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d4",
        "san" => "Qd4",
        "draw" => false,
        "prev_fen" => endgame.fen,
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      html = render(view)
      assert html =~ "Failed"
      assert html =~ "loses the draw"
      assert html =~ "Qd7"
    end

    test "solves when the user's move draws by rule", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      seed_tablebase(endgame.fen, category: :draw, moves: draw_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7",
        "draw" => true,
        "prev_fen" => endgame.fen,
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      assert render(view) =~ "Draw held!"
      assert Endgames.get_endgame!(endgame.id).times_solved == 1
    end

    test "solves when the opponent's reply draws by rule", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"
      reply = %Tablebase.Move{uci: "e8e7", san: "Ke7", category: :draw, dtz: nil}

      seed_tablebase(endgame.fen, category: :draw, moves: draw_moves())
      seed_tablebase(fen_after, category: :draw, moves: [reply])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7",
        "draw" => false,
        "prev_fen" => endgame.fen,
        "fen" => fen_after,
        "endgame_id" => endgame.id
      })

      render_hook(view, "opponent_reply_applied", %{"fen" => fen_after, "draw" => true})

      assert render(view) =~ "Draw held!"
      assert Endgames.get_endgame!(endgame.id).times_solved == 1
    end
  end

  describe "reset" do
    test "clears the move list and grade, and re-pushes init_board", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame}/play")

      play_move(view, endgame, "d1", "d7", "Qd7+")
      assert render(view) =~ "Qd7+"

      view |> element("button", "Reset") |> render_click()

      html = render(view)
      assert html =~ "No Moves"
      refute html =~ "Optimal move"
      assert_init_board(view, endgame.fen, "white", "white")
      assert Endgames.get_endgame!(endgame.id).times_attempted == 2
    end
  end
end
