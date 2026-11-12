defmodule ChesstrainerWeb.EndgameLive.PlayTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.FEN
  alias Chesstrainer.Ratelimiters
  alias Chesstrainer.Repo

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

    key = FEN.position_key(fen)
    TablebaseCache.put(key, tablebase)
    on_exit(fn -> TablebaseCache.delete(key) end)
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

  # >7-piece positions short-circuit to "not covered" before any backend, but
  # the changeset now rejects them, so insert one directly to exercise the path.
  defp insert_out_of_range_endgame do
    fen = "3k4/2n2B2/1KP5/2B2p2/5b1p/7P/8/8 b - - 0 1"
    {:ok, key} = Chesstrainer.Key.from_fen(fen)

    Chesstrainer.Repo.insert!(%Chesstrainer.Endgames.Endgame{
      public_code: Chesstrainer.Endgames.Endgame.generate_public_code(),
      fen: fen,
      color: :black,
      key: key,
      result: :win,
      rating: 1500.0
    })
  end

  # Plays one optimal move, applies the opponent's reply, then a losing move,
  # leaving a three-ply failed attempt to review.
  defp seeded_attempt(conn, start_moves \\ grading_moves()) do
    endgame = endgame_fixture()

    # The tablebase cache is keyed by position (clocks ignored), so these must
    # differ by more than the move clocks to stay distinct cache entries.
    after_first = "8/8/8/8/8/8/8/8 b - - 0 1"
    after_reply = "8/8/8/8/8/8/8/8 w - - 0 1"
    after_losing = "8/8/8/8/8/8/8/7K b - - 1 1"
    reply = %Tablebase.Move{uci: "e8e7", san: "Ke7", category: :loss, dtz: -3}
    losing_reply = %Tablebase.Move{uci: "e8e7", san: "Ke7", category: :draw, dtz: 0}

    seed_tablebase(endgame.fen, moves: start_moves)
    seed_tablebase(after_first, category: :loss, moves: [reply])
    seed_tablebase(after_reply, category: :win, moves: grading_moves())
    seed_tablebase(after_losing, category: :draw, moves: [losing_reply])

    {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

    %{proxy: {ref, _topic, _}} = view
    assert_receive {^ref, {:push_event, "init_board", _payload}}, 100

    render_hook(view, "endgame_move_played", %{
      "from" => "d1",
      "to" => "d7",
      "san" => "Qd7+",
      "prev_fen" => endgame.fen,
      "fen" => after_first,
      "endgame_id" => endgame.id
    })

    render_hook(view, "opponent_reply_applied", %{"fen" => after_reply})

    assert_receive {^ref, {:push_event, "opponent_move", _payload}}, 100
    assert_receive {^ref, {:push_event, "resume_board", _payload}}, 100

    render_hook(view, "endgame_move_played", %{
      "from" => "d1",
      "to" => "d4",
      "san" => "Qd4",
      "prev_fen" => after_reply,
      "fen" => after_losing,
      "endgame_id" => endgame.id
    })

    {view,
     %{
       start: endgame.fen,
       after_first: after_first,
       after_reply: after_reply,
       after_losing: after_losing
     }}
  end

  describe "mount" do
    test "renders the chessboard hook div and pushes init_board", %{conn: conn} do
      endgame = endgame_fixture(color: :white)
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert has_element?(view, "#endgame-board")
      assert_init_board(view, endgame.fen, "white", "white")
    end

    test "pushes black orientation when the endgame color is black", %{conn: conn} do
      endgame = endgame_fixture(color: :black)
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert_init_board(view, endgame.fen, "black", "black")
    end

    test "shows endgame metadata in the header", %{conn: conn} do
      endgame =
        endgame_fixture(
          fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1",
          color: :white,
          result: :win,
          rating: 1800
        )

      seed_tablebase(endgame.fen)

      {:ok, _view, html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert html =~ "KQ v K"
      assert html =~ "White to move"
      assert html =~ "1800"
      assert html =~ "max-w-2xl"
    end

    test "raises when the endgame does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/endgames/00000000-0000-0000-0000-000000000000/play")
      end
    end

    test "does not resolve by database id", %{conn: conn} do
      endgame = endgame_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, "/endgames/#{endgame.id}/play")
      end
    end
  end

  describe "current scope" do
    test "carries the signed-in user into the play screen", %{conn: conn} do
      user = Chesstrainer.AccountsFixtures.user_fixture()
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/endgames/#{endgame.public_code}/play")

      assert :sys.get_state(view.pid).socket.assigns.current_scope.user.id == user.id
    end

    test "is nil for an anonymous visitor", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert :sys.get_state(view.pid).socket.assigns.current_scope == nil
    end
  end

  describe "back link" do
    test "points home for an anonymous visitor", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert has_element?(view, ~s{a[href="/"]}, "Back home")
      refute has_element?(view, ~s{a[href="/endgames"]})
    end

    test "points home for a signed-in free user", %{conn: conn} do
      user = Chesstrainer.AccountsFixtures.user_fixture()
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/endgames/#{endgame.public_code}/play")

      assert has_element?(view, ~s{a[href="/"]}, "Back home")
      refute has_element?(view, ~s{a[href="/endgames"]})
    end

    test "points to the endgame index for a premium user", %{conn: conn} do
      {:ok, user} =
        Chesstrainer.AccountsFixtures.user_fixture()
        |> Ecto.Changeset.change(plan: :premium)
        |> Repo.update()

      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/endgames/#{endgame.public_code}/play")

      assert has_element?(view, ~s{a[href="/endgames"]}, "Back to endgames")
      refute has_element?(view, ~s{a[href="/"]}, "Back home")
    end
  end

  describe "tablebase availability" do
    test "blocks the attempt when the tablebase is cooling down", %{conn: conn} do
      # Six pieces routes to Lichess, so the cooldown applies (five or fewer
      # would be answered locally).
      endgame = endgame_fixture(fen: "8/8/5p2/1P1K1k2/8/2r5/8/7R w - - 0 1")
      TablebaseCache.delete(FEN.position_key(endgame.fen))
      Ratelimiters.lichess_add_cooldown()
      on_exit(fn -> Ratelimiters.lichess_reset_cooldown() end)

      {:ok, view, html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert html =~ "Tablebase unavailable"

      play_move(view, endgame, "d1", "d7", "Qd7+")
      assert render(view) =~ "cannot be graded"
    end

    test "blocks an out-of-range endgame as not covered", %{conn: conn} do
      endgame = insert_out_of_range_endgame()

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      html = render(view)
      assert html =~ "Tablebase unavailable"
      assert html =~ "not covered by the tablebase"
    end
  end

  describe "chess_fen_invalid" do
    test "shows a flash when the chessground hook reports an unparseable FEN", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play_move(view, endgame, "d1", "d7", "Qd7+")
      html = render(view)

      assert html =~ "Optimal move"
      assert html =~ "Qd7+"
    end

    test "grades a winning but slower move as winning", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play_move(view, endgame, "d1", "d5", "Qd5")

      assert render(view) =~ "Winning — but not the sharpest"
    end

    test "fails a move that throws the win away", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      assert render(view) =~ "Failed"
    end

    test "rejects a move that is out of sequence", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, _view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert Endgames.get_endgame!(endgame.id).times_attempted == 1
    end

    test "solves on checkmate", %{conn: conn} do
      endgame = endgame_fixture()
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"

      seed_tablebase(endgame.fen, moves: grading_moves())
      seed_tablebase(fen_after, checkmate: true, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      html = render(view)
      assert html =~ "Failed"
      assert html =~ "Qd7+"
      assert Endgames.get_endgame!(endgame.id).times_solved == 0
    end
  end

  describe "per-user attempt records" do
    setup :register_and_log_in_user

    test "records a solved attempt for the signed-in user", %{conn: conn, user: user} do
      endgame = endgame_fixture()
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"

      seed_tablebase(endgame.fen, moves: grading_moves())
      seed_tablebase(fen_after, checkmate: true, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "prev_fen" => endgame.fen,
        "fen" => fen_after,
        "endgame_id" => endgame.id
      })

      assert render(view) =~ "Solved!"
      assert render(view) =~ "Your rating is now"
      assert has_element?(view, "#your-rating")
      assert has_element?(view, "#rating-change")
      assert [attempt] = Repo.all(Attempt)
      assert attempt.user_id == user.id
      assert attempt.endgame_id == endgame.id
      assert attempt.outcome == :solved
    end

    test "shows a rating guide with the deviation band", %{conn: conn, user: user} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert has_element?(view, "#rating-guide")

      html = render(view)
      low = round(user.rating - 2 * user.rating_deviation)
      high = round(user.rating + 2 * user.rating_deviation)

      assert html =~ "Your rating: #{round(user.rating)}"
      assert html =~ "likely #{low}–#{high}"
    end

    test "records a failed attempt for the signed-in user", %{conn: conn, user: user} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      assert render(view) =~ "Failed"
      assert [attempt] = Repo.all(Attempt)
      assert attempt.user_id == user.id
      assert attempt.outcome == :failed
    end

    test "rates the user and the endgame on a solve", %{conn: conn, user: user} do
      endgame = endgame_fixture(rating: 1800)
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"

      seed_tablebase(endgame.fen, moves: grading_moves())
      seed_tablebase(fen_after, checkmate: true, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d7",
        "san" => "Qd7+",
        "prev_fen" => endgame.fen,
        "fen" => fen_after,
        "endgame_id" => endgame.id
      })

      rated_user = Repo.get!(User, user.id)

      assert render(view) =~ "Your rating: #{round(rated_user.rating)}"
      assert rated_user.rating > 1500.0
      assert Endgames.get_endgame!(endgame.id).rating < 1800.0
    end

    test "does not re-rate a replay within the window", %{conn: conn, user: user} do
      endgame = endgame_fixture(rating: 1800)
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"

      seed_tablebase(endgame.fen, moves: grading_moves())
      seed_tablebase(fen_after, checkmate: true, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play = fn ->
        render_hook(view, "endgame_move_played", %{
          "from" => "d1",
          "to" => "d7",
          "san" => "Qd7+",
          "prev_fen" => endgame.fen,
          "fen" => fen_after,
          "endgame_id" => endgame.id
        })
      end

      play.()
      rated_user = Repo.get!(User, user.id)
      rated_endgame = Endgames.get_endgame!(endgame.id)

      render_click(view, "reset")
      play.()

      html = render(view)

      assert html =~ "rating is unchanged"
      assert Repo.get!(User, user.id).rating == rated_user.rating
      assert Endgames.get_endgame!(endgame.id).rating == rated_endgame.rating
    end
  end

  describe "per-user attempt records without a signed-in user" do
    test "records nothing and leaves ratings untouched", %{conn: conn} do
      endgame = endgame_fixture(rating: 1800)
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      play_move(view, endgame, "d1", "d4", "Qd4")

      html = render(view)

      assert html =~ "Failed"
      refute html =~ "Your rating"
      assert Repo.aggregate(Attempt, :count) == 0
      assert Endgames.get_endgame!(endgame.id).rating == 1800.0
    end
  end

  describe "draw endgames" do
    test "loads and is playable", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      seed_tablebase(endgame.fen, category: :draw, moves: [])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      assert has_element?(view, "#endgame-board")
      assert render(view) =~ "Make a move"
    end

    test "passes a move that keeps the draw and replies", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)
      fen_after = "8/8/8/8/8/8/8/8 b - - 0 1"
      reply = %Tablebase.Move{uci: "e8e7", san: "Ke7", category: :draw, dtz: nil}

      seed_tablebase(endgame.fen, category: :draw, moves: draw_moves())
      seed_tablebase(fen_after, category: :draw, moves: [reply])

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

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

  describe "full move list" do
    test "shows the opponent's reply alongside the user's moves", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      html = render(view)
      assert html =~ "Qd7+"
      assert html =~ "Ke7"
      assert html =~ "Qd4"
    end

    test "colours the user's plies by grade", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      html = render(view)
      assert html =~ ~s(data-grade="optimal")
      assert html =~ ~s(data-grade="losing")
    end

    test "uses draw-aware wording for draw attempts", %{conn: conn} do
      endgame = endgame_fixture(result: :draw)

      moves = [
        %Tablebase.Move{uci: "d1d7", san: "Qd7", category: :draw, dtz: 0},
        %Tablebase.Move{uci: "d1d5", san: "Qd5", category: :draw, dtz: -5}
      ]

      seed_tablebase(endgame.fen, category: :draw, moves: moves)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "d1",
        "to" => "d5",
        "san" => "Qd5",
        "prev_fen" => endgame.fen,
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      html = render(view)
      assert html =~ "Keeps the draw"
      refute html =~ "Winning — but not the sharpest"
    end
  end

  describe "review" do
    test "enters review after a failed attempt at the final position", %{conn: conn} do
      {view, fens} = seeded_attempt(conn)

      assert has_element?(view, "button", "Review")

      view |> element("button", "Review") |> render_click()

      %{proxy: {ref, _topic, _}} = view
      assert_receive {^ref, {:push_event, "review_position", %{fen: fen}}}, 100
      assert fen == fens.after_losing
      assert has_element?(view, "#review-controls")
    end

    test "offers review after a solved attempt", %{conn: conn} do
      endgame = endgame_fixture()
      moves = [%Tablebase.Move{uci: "a7a8q", san: "a8=Q", category: :loss, dtz: -1}]
      seed_tablebase(endgame.fen, moves: moves)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      render_hook(view, "endgame_move_played", %{
        "from" => "a7",
        "to" => "a8",
        "san" => "a8=Q",
        "promotion" => "q",
        "prev_fen" => endgame.fen,
        "fen" => endgame.fen,
        "endgame_id" => endgame.id
      })

      assert has_element?(view, "button", "Review")
    end

    test "steps through positions with prev/next and clamps at the ends", %{conn: conn} do
      {view, fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()

      %{proxy: {ref, _topic, _}} = view

      assert_receive {^ref, {:push_event, "review_position", %{fen: after_losing}}}, 100
      assert after_losing == fens.after_losing

      render_hook(view, "review_prev", %{})

      assert_receive {^ref, {:push_event, "review_position", %{fen: after_reply}}}, 100
      assert after_reply == fens.after_reply

      render_hook(view, "review_prev", %{})

      assert_receive {^ref, {:push_event, "review_position", %{fen: after_first}}}, 100
      assert after_first == fens.after_first

      render_hook(view, "review_prev", %{})

      assert_receive {^ref, {:push_event, "review_position", %{fen: start}}}, 100
      assert start == fens.start

      # Bounded at the start of the game.
      render_hook(view, "review_prev", %{})

      assert_receive {^ref, {:push_event, "review_position", %{fen: still_start}}}, 100
      assert still_start == fens.start

      render_hook(view, "review_next", %{})

      assert_receive {^ref, {:push_event, "review_position", %{fen: back}}}, 100
      assert back == fens.after_first
    end

    test "hides the result panels and move list while reviewing", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()

      assert has_element?(view, "#best-move-panel")
      refute has_element?(view, "#move-list")
      refute render(view) =~ "Failed"
      refute render(view) =~ "Solved!"
    end

    test "jumps to the start and end of the reviewed line", %{conn: conn} do
      {view, fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()

      %{proxy: {ref, _topic, _}} = view
      assert_receive {^ref, {:push_event, "review_position", %{fen: after_losing}}}, 100
      assert after_losing == fens.after_losing

      view |> element("#review-start") |> render_click()

      assert_receive {^ref, {:push_event, "review_position", %{fen: start}}}, 100
      assert start == fens.start

      view |> element("#review-end") |> render_click()

      assert_receive {^ref, {:push_event, "review_position", %{fen: at_end}}}, 100
      assert at_end == fens.after_losing
    end

    test "try again exits review and starts a fresh attempt", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()
      assert has_element?(view, "#review-controls")

      view |> element("button", "Try again") |> render_click()

      refute has_element?(view, "#review-controls")
      assert render(view) =~ "No Moves"

      %{proxy: {ref, _topic, _}} = view
      assert_receive {^ref, {:push_event, "init_board", _payload}}, 100
    end

    test "ignores moves while reviewing", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()

      render_hook(view, "endgame_move_played", %{
        "from" => "a1",
        "to" => "a2",
        "san" => "Ka2",
        "prev_fen" => "8/8/8/8/8/8/8/8 b - - 1 1",
        "fen" => "8/8/8/8/8/8/8/8 w - - 1 2",
        "endgame_id" => "ignored"
      })

      refute render(view) =~ "Ka2"
    end
  end

  describe "best moves" do
    test "shows the best move and the played move at each reviewed position", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()

      panel = view |> element("#best-move-panel") |> render()
      assert panel =~ "Best move:"
      assert panel =~ "Ke7"

      render_hook(view, "review_prev", %{})

      panel = view |> element("#best-move-panel") |> render()
      assert panel =~ "Qd7+"
      assert panel =~ "Played: Qd4"
    end

    test "groups tablebase moves by outcome during review", %{conn: conn} do
      start_moves = [
        %Tablebase.Move{uci: "d1d7", san: "Qd7+", category: :loss, dtz: -1},
        %Tablebase.Move{uci: "d1d4", san: "Qd4", category: :draw, dtz: 0},
        %Tablebase.Move{uci: "d1d8", san: "Qd8", category: :win, dtz: 5}
      ]

      {view, _fens} = seeded_attempt(conn, start_moves)

      view |> element("button", "Review") |> render_click()
      render_hook(view, "review_step", %{"index" => "0"})

      panel = view |> element("#best-move-panel") |> render()

      assert panel =~ ~r/Winning.*Qd7\+.*Drawn.*Qd4.*Losing.*Qd8/s
      assert panel =~ "DTZ 1"
      assert panel =~ "DTZ 5"
    end

    test "clicking a tablebase move plays it from the reviewed position", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()
      render_hook(view, "review_step", %{"index" => "2"})

      %{proxy: {ref, _topic, _}} = view
      assert_receive {^ref, {:push_event, "review_position", _}}, 100
      assert_receive {^ref, {:push_event, "review_position", _}}, 100

      view |> element("#best-move-panel button[phx-value-uci='d1d5']") |> render_click()

      assert_receive {^ref, {:push_event, "best_line_move", %{from: "d1", to: "d5"}}}, 100

      best_after = "8/8/8/8/8/8/8/6K1 b - - 1 1"

      seed_tablebase(best_after,
        category: :draw,
        moves: [%Tablebase.Move{uci: "g1g2", san: "Kg2", category: :draw, dtz: 0}]
      )

      render_hook(view, "best_line_move_applied", %{"fen" => best_after})

      assert_receive {^ref, {:push_event, "review_position", %{fen: ^best_after}}}, 100

      panel = view |> element("#best-move-panel") |> render()
      assert panel =~ "Kg2"
      assert has_element?(view, "button", "Back to game")
      refute has_element?(view, "#move-list")
    end

    test "summarises the failing move and the best alternative", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      assert render(view) =~ "You played Qd4; best was: Qd7+"
    end

    test "play best line branches and steps the optimal continuation", %{conn: conn} do
      {view, fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()
      render_hook(view, "review_prev", %{})

      %{proxy: {ref, _topic, _}} = view
      assert_receive {^ref, {:push_event, "review_position", _}}, 100
      assert_receive {^ref, {:push_event, "review_position", _}}, 100

      view |> element("button", "Play best line") |> render_click()

      assert_receive {^ref, {:push_event, "best_line_move", %{from: "d1", to: "d7"}}}, 100

      best_after = "8/8/8/8/8/8/8/8 w - - 2 1"

      seed_tablebase(best_after,
        category: :draw,
        moves: [%Tablebase.Move{uci: "d8d7", san: "Qd7", category: :draw, dtz: 0}]
      )

      render_hook(view, "best_line_move_applied", %{"fen" => best_after})

      assert_receive {^ref, {:push_event, "review_position", %{fen: ^best_after}}}, 100

      panel = view |> element("#best-move-panel") |> render()
      assert panel =~ "Qd7"
      assert has_element?(view, "button", "Back to game")

      view |> element("button", "Back to game") |> render_click()

      assert_receive {^ref, {:push_event, "review_position", %{fen: fen}}}, 100
      assert fen == fens.after_losing
      refute has_element?(view, "button", "Back to game")
    end

    test "degrades gracefully and reuses played-position snapshots", %{conn: conn} do
      {view, fens} = seeded_attempt(conn)

      TablebaseCache.delete(FEN.position_key(fens.after_losing))
      Ratelimiters.lichess_add_cooldown()
      on_exit(fn -> Ratelimiters.lichess_reset_cooldown() end)

      view |> element("button", "Review") |> render_click()

      panel = view |> element("#best-move-panel") |> render()
      assert panel =~ "Best move unavailable here"
      refute has_element?(view, "button", "Play best line")

      render_hook(view, "review_prev", %{})

      panel = view |> element("#best-move-panel") |> render()
      refute panel =~ "Best move unavailable here"
      assert panel =~ "Qd7+"
    end
  end

  describe "keyboard move input" do
    defp open_with_moves(conn) do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())
      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")
      view
    end

    test "accepts SAN and asks the board to apply it", %{conn: conn} do
      view = open_with_moves(conn)
      %{proxy: {ref, _topic, _}} = view

      view |> form("#move-input-form", move: "Qd7+") |> render_submit()

      assert_receive {^ref, {:push_event, "apply_move", %{from: "d1", to: "d7", san: "Qd7+"}}},
                     100
    end

    test "accepts UCI", %{conn: conn} do
      view = open_with_moves(conn)
      %{proxy: {ref, _topic, _}} = view

      view |> form("#move-input-form", move: "d1d5") |> render_submit()

      assert_receive {^ref, {:push_event, "apply_move", %{from: "d1", to: "d5"}}}, 100
    end

    test "reports an illegal move without asking the board to play it", %{conn: conn} do
      view = open_with_moves(conn)
      %{proxy: {ref, _topic, _}} = view

      html = view |> form("#move-input-form", move: "Qh8") |> render_submit()

      assert html =~ "Not a legal move here"
      refute_receive {^ref, {:push_event, "apply_move", _}}, 100
    end

    test "labels the input and explains both move formats", %{conn: conn} do
      view = open_with_moves(conn)

      assert has_element?(view, "label[for='move-input']", "Your move")
      assert has_element?(view, "#move-input-help", "SAN or UCI")
      assert has_element?(view, "#move-input[aria-describedby='move-input-help']")
    end
  end

  describe "screen reader announcements" do
    test "announces the opening position and whose move it is", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen)

      {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

      announcer = view |> element("#board-announcer") |> render()
      assert announcer =~ "You play White."
      assert announcer =~ "White to move."

      summary = view |> element("#position-summary") |> render()
      assert summary =~ "king on"
    end

    test "announces a failed puzzle and the best move", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      announcer = view |> element("#board-announcer") |> render()
      assert announcer =~ "Failed."
      assert announcer =~ "Best was"
    end

    test "announces the reviewed position", %{conn: conn} do
      {view, _fens} = seeded_attempt(conn)

      view |> element("button", "Review") |> render_click()

      announcer = view |> element("#board-announcer") |> render()
      assert announcer =~ "Reviewing position"
      assert announcer =~ "After Qd4"
    end
  end
end
