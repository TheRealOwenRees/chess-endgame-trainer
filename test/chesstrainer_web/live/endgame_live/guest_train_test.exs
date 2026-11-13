defmodule ChesstrainerWeb.EndgameLive.GuestTrainTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.FEN
  alias Chesstrainer.GuestLimits
  alias Chesstrainer.Repo

  @guest_address {127, 0, 0, 1}

  setup do
    GuestLimits.reset()
    :ok
  end

  defp seed_tablebase(fen, opts) do
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

  # Plays the move the seeded tablebase grades as optimal and completes the
  # puzzle by checkmate on the follow-up position.
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

  defp spend_puzzles(count) do
    for _ <- 1..count do
      assert {:ok, _remaining} = GuestLimits.take(@guest_address)
    end
  end

  describe "access" do
    test "lets an anonymous visitor play a random puzzle", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/guest-train")

      assert has_element?(view, "#endgame-board[data-endgame-id='#{endgame.id}']")
      refute has_element?(view, "#difficulty-picker")
      refute has_element?(view, "#session-bar")
      assert render(view) =~ "A random endgame puzzle"
      assert render(view) =~ "4 of 5 free puzzles left today"
    end

    test "redirects signed-in users to the difficulty picker", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/train"}}} = live(conn, ~p"/guest-train")
    end
  end

  describe "without puzzles" do
    test "shows an empty state with a retry that does not spend a puzzle", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/guest-train")

      assert has_element?(view, "#guest-pool-empty")
      assert has_element?(view, "#retry-pool")
      refute has_element?(view, "#endgame-board")
      assert {:ok, 5} = GuestLimits.remaining(@guest_address)

      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      view |> element("#retry-pool") |> render_click()

      assert has_element?(view, "#endgame-board")
      assert :sys.get_state(view.pid).socket.assigns.guest_remaining == 4
    end
  end

  describe "playing" do
    test "solves a puzzle without recording an attempt", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/guest-train")

      solve_current(view)

      assert render(view) =~ "Solved!"
      assert has_element?(view, "#next-puzzle-button")
      assert Repo.aggregate(Attempt, :count) == 0
    end

    test "next puzzle loads a different endgame", %{conn: conn} do
      endgames =
        for _ <- 1..2 do
          endgame = endgame_fixture()
          seed_tablebase(endgame.fen, moves: grading_moves())
          endgame
        end

      {:ok, view, _html} = live(conn, ~p"/guest-train")
      first = :sys.get_state(view.pid).socket.assigns.endgame

      solve_current(view)
      view |> element("#next-puzzle-button") |> render_click()

      second = :sys.get_state(view.pid).socket.assigns.endgame
      assert second.id != first.id
      assert Enum.any?(endgames, &(&1.id == second.id))
      assert :sys.get_state(view.pid).socket.assigns.guest_remaining == 3
    end

    test "trying again does not spend another puzzle", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/guest-train")

      solve_current(view)
      view |> element("button", "Try again") |> render_click()

      assert :sys.get_state(view.pid).socket.assigns.guest_remaining == 4
    end

    test "shows an in-page state when no puzzles are left, and retry loads one", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      {:ok, view, _html} = live(conn, ~p"/guest-train")
      solve_current(view)

      Repo.delete!(endgame)

      view |> element("#next-puzzle-button") |> render_click()

      assert has_element?(view, "#guest-pool-exhausted")
      assert has_element?(view, "#retry-pool")
      refute has_element?(view, "#endgame-board")
      assert :sys.get_state(view.pid).socket.assigns.guest_remaining == 4

      new_endgame = endgame_fixture()
      seed_tablebase(new_endgame.fen, moves: grading_moves())

      view |> element("#retry-pool") |> render_click()

      assert :sys.get_state(view.pid).socket.assigns.endgame.id == new_endgame.id
      assert :sys.get_state(view.pid).socket.assigns.guest_remaining == 3
    end
  end

  describe "daily budget" do
    test "shows the sign-up wall once the budget is spent", %{conn: conn} do
      endgame = endgame_fixture()
      seed_tablebase(endgame.fen, moves: grading_moves())

      spend_puzzles(4)

      {:ok, view, _html} = live(conn, ~p"/guest-train")
      assert :sys.get_state(view.pid).socket.assigns.guest_remaining == 0
      assert render(view) =~ "Last free puzzle today"

      solve_current(view)
      view |> element("#next-puzzle-button") |> render_click()

      assert has_element?(view, "#guest-limit")
      assert render(view) =~ "used your 5 free puzzles today"
      assert render(view) =~ "Sign up for a free account to keep training"
      assert has_element?(view, "#guest-sign-up[href='/users/register']")
      assert render(view) =~ "reset at 00:00 UTC"
      refute has_element?(view, "#next-puzzle-button")
    end

    test "a fresh visit after the limit shows only the wall", %{conn: conn} do
      spend_puzzles(5)

      {:ok, view, _html} = live(conn, ~p"/guest-train")

      assert has_element?(view, "#guest-limit")
      refute has_element?(view, "#endgame-board")
      assert render(view) =~ "used your 5 free puzzles today"
    end

    test "signed-in visitors do not spend the guest budget", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, {:redirect, %{to: "/train"}}} = live(conn, ~p"/guest-train")

      assert {:ok, 4} = GuestLimits.take(@guest_address)
    end
  end
end
