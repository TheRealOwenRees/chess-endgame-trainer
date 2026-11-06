defmodule ChesstrainerWeb.EndgameLive.TrainTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.FEN
  alias Chesstrainer.Repo

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
    [%Tablebase.Move{uci: "d1d7", san: "Qd7+", category: :loss, dtz: -1}]
  end

  # Sets up `count` endgames all inside the medium band, seeds their tablebases,
  # and starts a medium session. Returns the view and the endgames.
  @session_fens [
    "4k3/8/8/8/8/8/8/1K6 w - - 0 1",
    "4k3/8/8/8/8/8/8/2K5 w - - 0 1",
    "4k3/8/8/8/8/8/8/3K4 w - - 0 1"
  ]

  defp start_medium_session(conn, count) do
    endgames =
      for index <- 0..(count - 1) do
        endgame_fixture(fen: Enum.fetch!(@session_fens, index), rating: 1500)
      end

    Enum.each(endgames, fn endgame ->
      seed_tablebase(endgame.fen, moves: grading_moves())
    end)

    {:ok, view, _html} = live(conn, ~p"/train")

    view
    |> element("#difficulty-medium")
    |> render_click()

    {view, endgames}
  end

  defp solve_current(view) do
    endgame = :sys.get_state(view.pid).socket.assigns.endgame
    after_fen = "8/8/8/8/8/8/8/8 b - - 0 1"

    seed_tablebase(after_fen, checkmate: true, moves: [])

    render_hook(view, "endgame_move_played", %{
      "from" => "d1",
      "to" => "d7",
      "san" => "Qd7+",
      "prev_fen" => endgame.fen,
      "fen" => after_fen,
      "endgame_id" => endgame.id
    })
  end

  describe "access" do
    test "redirects anonymous visitors to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/train")
    end
  end

  describe "starting a session" do
    setup :register_and_log_in_user

    test "shows the difficulty picker with all three choices", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/train")

      assert has_element?(view, "#difficulty-picker")
      assert has_element?(view, "#difficulty-easy")
      assert has_element?(view, "#difficulty-medium")
      assert has_element?(view, "#difficulty-hard")
      assert has_element?(view, "#close-difficulty[href='/']")
      assert has_element?(view, "a", "Cancel")
      refute has_element?(view, "#puzzle-search")
      assert render(view) =~ "Choose a difficulty"
    end

    test "starts a medium session and shows the session chrome", %{conn: conn} do
      endgame = endgame_fixture(rating: 1500)
      seed_tablebase(endgame.fen)
      {:ok, view, _html} = live(conn, ~p"/train")

      view |> element("#difficulty-medium") |> render_click()

      refute has_element?(view, "#difficulty-picker")
      assert has_element?(view, "#session-bar")
      assert has_element?(view, "#session-clock-" <> Integer.to_string(elapsed_id(view)))
      assert has_element?(view, "#endgame-board")

      html = render(view)
      assert html =~ "Your move"
      assert html =~ "You play White"

      session = :sys.get_state(view.pid).socket.assigns.session
      assert session.difficulty == :medium
      assert session.count == 0
    end
  end

  describe "premium access" do
    test "shows the puzzle search link for premium users", %{conn: conn} do
      {:ok, user} =
        user_fixture()
        |> Ecto.Changeset.change(plan: :premium)
        |> Repo.update()

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/train")

      assert has_element?(view, "#puzzle-search[href='/endgames']")
      assert render(view) =~ "Puzzle Search"
    end
  end

  describe "playing a session" do
    setup :register_and_log_in_user

    test "solves a puzzle, records an attempt and shows the rating gain", %{conn: conn} do
      {view, [_endgame]} = start_medium_session(conn, 1)

      solve_current(view)

      assert render(view) =~ "Solved!"
      assert render(view) =~ "Puzzle rating:"
      assert [attempt] = Repo.all(Attempt)
      assert attempt.outcome == :solved

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.session.count == 1
      assert is_float(assigns.last_rating_delta)
      assert assigns.last_rating_delta > 0
      assert assigns.user_rating > 1500.0
    end

    test "loads a different puzzle on next", %{conn: conn} do
      {view, endgames} = start_medium_session(conn, 2)
      first = :sys.get_state(view.pid).socket.assigns.endgame

      solve_current(view)
      view |> element("#next-puzzle-button") |> render_click()

      second = :sys.get_state(view.pid).socket.assigns.endgame
      assert second.id != first.id
      assert Enum.any?(endgames, &(&1.id == second.id))
    end

    test "keeps next puzzle available while reviewing", %{conn: conn} do
      {view, endgames} = start_medium_session(conn, 2)
      first = :sys.get_state(view.pid).socket.assigns.endgame

      solve_current(view)
      view |> element("button", "Review") |> render_click()

      assert has_element?(view, "#next-puzzle-button")
      view |> element("#next-puzzle-button") |> render_click()

      second = :sys.get_state(view.pid).socket.assigns.endgame
      assert second.id != first.id
      assert Enum.any?(endgames, &(&1.id == second.id))
      refute :sys.get_state(view.pid).socket.assigns.reviewing
    end

    test "a retry does not count toward the average again", %{conn: conn} do
      {view, [_endgame]} = start_medium_session(conn, 1)

      solve_current(view)
      assert :sys.get_state(view.pid).socket.assigns.session.count == 1

      view |> element("button", "Try again") |> render_click()
      solve_current(view)

      assert :sys.get_state(view.pid).socket.assigns.session.count == 1
    end

    test "stopping shows the finished session in the picker", %{conn: conn} do
      {view, [_endgame]} = start_medium_session(conn, 1)
      solve_current(view)

      view |> element("button", "Stop session") |> render_click()

      assert has_element?(view, "#last-session")
      assert render(view) =~ "Last session"

      last = :sys.get_state(view.pid).socket.assigns.last_session
      assert last.difficulty == :medium
      assert last.count == 1
      assert is_float(last.gain)
      assert last.gain > 0
      assert last.duration_ms >= 0
    end

    test "stopping a session returns to the picker so a new one can start", %{conn: conn} do
      {view, [_endgame]} = start_medium_session(conn, 1)

      view |> element("button", "Stop session") |> render_click()

      assert has_element?(view, "#difficulty-picker")
      assert has_element?(view, "#difficulty-medium")
      assert :sys.get_state(view.pid).socket.assigns.session == nil
    end
  end

  defp elapsed_id(view) do
    :sys.get_state(view.pid).socket.assigns.session.started_at_ms
  end
end
