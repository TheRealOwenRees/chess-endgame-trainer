defmodule ChesstrainerWeb.HomeBoardLiveTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.FEN
  alias Chesstrainer.Themes
  alias ChesstrainerWeb.HomeBoardLive

  @fen "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"

  defp create_endgame do
    {:ok, theme} = Themes.create_theme(%{name: "Opposition", category: :endgame})

    {:ok, endgame} =
      Endgames.create_endgame(
        %{fen: @fen, color: :white, result: :win, rating: 1500},
        [theme]
      )

    endgame
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

  defp fen_after(moves) do
    moves
    |> Enum.reduce_while(Chex.Game.new(@fen), fn {from, to}, {:ok, game} ->
      case Chex.Game.move(game, {from, to}) do
        {:ok, game} -> {:cont, {:ok, game}}
        error -> {:halt, error}
      end
    end)
    |> then(fn {:ok, game} ->
      {:ok, fen} = Chex.Parser.FEN.serialize(game)
      fen
    end)
  end

  defp mount_board(conn, endgame) do
    live_isolated(conn, HomeBoardLive, session: %{"home_endgame_code" => endgame.public_code})
  end

  defp click_square(view, square) do
    view |> element(~s(button[phx-value-square="#{square}"])) |> render_click()
  end

  test "shows the endgame theme and highlights legal moves", %{conn: conn} do
    endgame = create_endgame()

    seed_tablebase(@fen,
      category: :win,
      moves: [%Tablebase.Move{uci: "f3f4", san: "Rf4", category: :loss, dtz: -1}]
    )

    {:ok, view, html} = mount_board(conn, endgame)

    assert html =~ "Opposition"
    assert html =~ endgame.key
    assert html =~ "Your move"

    click_square(view, "f3")

    assert has_element?(view, ".square.selected")
    assert has_element?(view, ".square.target")
  end

  test "solves when the move leads to checkmate", %{conn: conn} do
    endgame = create_endgame()

    seed_tablebase(@fen,
      category: :win,
      moves: [%Tablebase.Move{uci: "f3f4", san: "Rf4", category: :loss, dtz: -1}]
    )

    seed_tablebase(fen_after([{{:f, 3}, {:f, 4}}]), category: :win, checkmate: true, moves: [])

    {:ok, view, _html} = mount_board(conn, endgame)

    click_square(view, "f3")
    click_square(view, "f4")

    assert render(view) =~ "Solved!"
    assert has_element?(view, "button", "Try again")
  end

  test "opponent replies and play continues", %{conn: conn} do
    endgame = create_endgame()

    seed_tablebase(@fen,
      category: :win,
      moves: [%Tablebase.Move{uci: "f3f4", san: "Rf4", category: :loss, dtz: -1}]
    )

    seed_tablebase(fen_after([{{:f, 3}, {:f, 4}}]),
      category: :loss,
      moves: [%Tablebase.Move{uci: "d6e6", san: "Ke6", category: :win, dtz: -2}]
    )

    seed_tablebase(fen_after([{{:f, 3}, {:f, 4}}, {{:d, 6}, {:e, 6}}]), category: :win, moves: [])

    {:ok, view, _html} = mount_board(conn, endgame)

    click_square(view, "f3")
    click_square(view, "f4")

    assert render(view) =~ "Your move"
    refute render(view) =~ "Failed"
    refute render(view) =~ "Solved!"
  end

  test "fails when the move throws away the win", %{conn: conn} do
    endgame = create_endgame()

    seed_tablebase(@fen,
      category: :win,
      moves: [%Tablebase.Move{uci: "f3f4", san: "Rf4", category: :draw, dtz: 0}]
    )

    {:ok, view, _html} = mount_board(conn, endgame)

    click_square(view, "f3")
    click_square(view, "f4")

    assert render(view) =~ "Failed"
  end

  test "Try again resets to a playable position", %{conn: conn} do
    endgame = create_endgame()

    seed_tablebase(@fen,
      category: :win,
      moves: [%Tablebase.Move{uci: "f3f4", san: "Rf4", category: :draw, dtz: 0}]
    )

    {:ok, view, _html} = mount_board(conn, endgame)

    click_square(view, "f3")
    click_square(view, "f4")
    assert render(view) =~ "Failed"

    view |> element("button", "Try again") |> render_click()

    assert render(view) =~ "Your move"
    refute render(view) =~ "Failed"
  end
end
