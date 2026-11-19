defmodule ChesstrainerWeb.EndgameLive.TrainTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames
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
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/train/lucena")
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
      assert has_element?(view, "a", "Return Home")
      assert has_element?(view, "#connection-actions")
      assert render(view) =~ ">Reload<"
      assert has_element?(view, "#puzzle-search[href='/endgames']")
      assert has_element?(view, "#rating-guide")
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

  describe "browsing endgames" do
    setup :register_and_log_in_user

    test "free users get the browse link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/train")

      assert has_element?(view, "#puzzle-search[href='/endgames']")
      assert render(view) =~ "Browse endgames"
    end
  end

  describe "themed sessions" do
    setup %{conn: conn} do
      {:ok, user} = Accounts.update_user_plan(user_fixture(), :premium)
      %{conn: log_in_user(conn, user)}
    end

    test "resolves the slug and only serves endgames carrying the theme", %{conn: conn} do
      theme = theme_fixture(%{name: "Lucena"})
      themed = endgame_fixture(fen: Enum.fetch!(@session_fens, 0), rating: 1500)
      _other = endgame_fixture(fen: Enum.fetch!(@session_fens, 1), rating: 1500)
      {:ok, _} = Endgames.update_endgame(themed, %{}, [theme])
      seed_tablebase(themed.fen, moves: grading_moves())

      {:ok, view, html} = live(conn, ~p"/train/#{theme.slug}")

      assert html =~ "Train Lucena"
      assert has_element?(view, "#difficulty-medium")

      view |> element("#difficulty-medium") |> render_click()

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.endgame.id == themed.id
      assert assigns.session.collection_label == "Lucena"
      assert has_element?(view, "#session-theme", "Lucena")
    end

    test "stops with a themed exhaustion message and a link to unfiltered training", %{
      conn: conn
    } do
      theme = theme_fixture(%{name: "Lucena"})
      only = endgame_fixture(fen: Enum.fetch!(@session_fens, 0), rating: 1500)
      {:ok, _} = Endgames.update_endgame(only, %{}, [theme])
      seed_tablebase(only.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/train/#{theme.slug}")
      view |> element("#difficulty-medium") |> render_click()

      solve_current(view)
      view |> element("#next-puzzle-button") |> render_click()

      assert has_element?(view, "#pool-exhausted", "Lucena")
      assert has_element?(view, "#train-unfiltered[href='/train']")
      assert render(view) =~ "Play the whole library"
    end

    test "plays a collection built from the query grammar", %{conn: conn} do
      lucena = theme_fixture(%{name: "Lucena"})
      philidor = theme_fixture(%{name: "Philidor"})
      kr_fen = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
      kq_fen = "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1"
      kr = endgame_fixture(fen: kr_fen, rating: 1500)
      _kq = endgame_fixture(fen: kq_fen, rating: 1500)
      {:ok, _} = Endgames.update_endgame(kr, %{}, [lucena, philidor])
      seed_tablebase(kr.fen, moves: grading_moves())

      {:ok, view, _html} =
        live(conn, ~p"/train?themes=lucena,philidor&key=KR+v+K")

      assert render(view) =~ "Train Lucena, Philidor · KR v K"

      view |> element("#difficulty-medium") |> render_click()

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.endgame.id == kr.id
      assert assigns.session.collection_label == "Lucena, Philidor · KR v K"
      assert assigns.session.key == "KR v K"
      assert has_element?(view, "#session-theme", "Lucena, Philidor · KR v K")
    end
  end

  describe "themed access" do
    setup :register_and_log_in_user

    test "unknown slugs render the branded 404", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/train/no-such-theme")

      assert render(view) =~ "on the board"
      assert has_element?(view, ".error-page")
    end

    test "free users can train a theme", %{conn: conn} do
      theme = theme_fixture(%{name: "Lucena"})

      {:ok, view, _html} = live(conn, ~p"/train/#{theme.slug}")

      assert has_element?(view, "#difficulty-picker")
      assert render(view) =~ "Train Lucena"
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
      assert assigns.user_deviation < 350.0

      assert has_element?(view, "#session-rating")
      assert has_element?(view, "#session-rating-change")
      assert has_element?(view, "#rating-change")
      assert render(view) =~ "Your rating is now"
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

    test "does not serve the same puzzle twice in a session", %{conn: conn} do
      {view, [only]} = start_medium_session(conn, 1)

      solve_current(view)
      view |> element("#next-puzzle-button") |> render_click()

      assigns = :sys.get_state(view.pid).socket.assigns
      assert has_element?(view, "#pool-exhausted")
      assert assigns.endgame.id == only.id
      assert assigns.session.served_ids == [only.id]
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
      assert last.rating > 1500.0
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

  describe "empty pools" do
    setup :register_and_log_in_user

    test "shows an in-page state when a difficulty has no puzzles", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/train")

      view |> element("#difficulty-medium") |> render_click()

      assert has_element?(view, "#pool-empty")
      assert has_element?(view, "#retry-pool")
      assert has_element?(view, "#difficulty-picker")
      refute has_element?(view, "#session-bar")

      endgame = endgame_fixture(rating: 1500)
      seed_tablebase(endgame.fen)

      view |> element("#retry-pool") |> render_click()

      assert has_element?(view, "#session-bar")
      refute has_element?(view, "#pool-empty")
    end

    test "shows an in-page end-of-run state when the difficulty is exhausted", %{conn: conn} do
      {view, [_endgame]} = start_medium_session(conn, 1)
      solve_current(view)

      view |> element("#next-puzzle-button") |> render_click()

      assert has_element?(view, "#pool-exhausted")
      assert has_element?(view, "#retry-pool")
      assert has_element?(view, "#change-difficulty")
      refute has_element?(view, "#endgame-board")

      view |> element("#change-difficulty") |> render_click()

      assert has_element?(view, "#difficulty-picker")
      assert :sys.get_state(view.pid).socket.assigns.session == nil
    end

    test "retry loads a puzzle once the pool grows", %{conn: conn} do
      {view, [_endgame]} = start_medium_session(conn, 1)
      solve_current(view)

      view |> element("#next-puzzle-button") |> render_click()
      assert has_element?(view, "#pool-exhausted")

      rating = :sys.get_state(view.pid).socket.assigns.user_rating
      new_endgame = endgame_fixture(fen: "4k3/8/8/8/8/8/8/4K3 w - - 0 1", rating: round(rating))
      seed_tablebase(new_endgame.fen)

      view |> element("#retry-pool") |> render_click()

      assert :sys.get_state(view.pid).socket.assigns.endgame.id == new_endgame.id
      refute has_element?(view, "#pool-exhausted")
    end
  end

  defp elapsed_id(view) do
    :sys.get_state(view.pid).socket.assigns.session.started_at_ms
  end
end
