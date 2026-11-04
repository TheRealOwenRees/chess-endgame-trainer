defmodule ChesstrainerWeb.HomeLiveTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Cache, as: TablebaseCache
  alias Chesstrainer.FEN
  alias Chesstrainer.Themes

  @fen_kr "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
  @fen_kr_other "8/8/4k3/8/8/3K1R2/8/8 w - - 0 1"
  @fen_kq "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1"

  setup do
    previous = Application.get_env(:chesstrainer, :curated_endgame_codes)
    on_exit(fn -> Application.put_env(:chesstrainer, :curated_endgame_codes, previous) end)
    :ok
  end

  defp create_endgame(fen, rating, theme_name) do
    {:ok, theme} = Themes.create_theme(%{name: theme_name, category: :endgame})

    {:ok, endgame} =
      Endgames.create_endgame(%{fen: fen, color: :white, result: :win, rating: rating}, [theme])

    endgame
  end

  defp curated! do
    beginner = create_endgame(@fen_kr, 1500, "Opposition")
    intermediate = create_endgame(@fen_kr_other, 1800, "Lucena")
    advanced = create_endgame(@fen_kq, 2100, "Philidor")

    Application.put_env(:chesstrainer, :curated_endgame_codes, [
      beginner.public_code,
      intermediate.public_code,
      advanced.public_code
    ])

    {beginner, intermediate, advanced}
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

  defp fen_after(fen, moves) do
    moves
    |> Enum.reduce_while(Chex.Game.new(fen), fn {from, to}, {:ok, game} ->
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

  defp click_square(view, square) do
    view |> element(~s(button[phx-value-square="#{square}"])) |> render_click()
  end

  test "GET / renders the landing page and navbar", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "Learn to see the"
    assert html =~ "LUCID"
    assert html =~ "Method"
    assert html =~ "Puzzles"
    assert html =~ "Start training"
    assert html =~ ~s(id="nav-links")
    assert html =~ "menu-button"
    assert html =~ "No endgames yet"
  end

  test "guest navbar links to log in and register", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~p"/users/log-in"
    assert html =~ ~p"/users/register"
    refute html =~ ~p"/users/settings"
  end

  test "signed-in navbar links to settings and log out", %{conn: conn} do
    html =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~p"/users/settings"
    assert html =~ ~p"/users/log-out"
    refute html =~ ~p"/users/register"
  end

  test "renders curated cards and the first endgame's board", %{conn: conn} do
    {beginner, intermediate, advanced} = curated!()
    seed_tablebase(beginner.fen, category: :win, moves: [])

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             ~s(.puzzle-card.active[phx-value-code="#{beginner.public_code}"])
           )

    assert has_element?(
             view,
             ~s(.puzzle-card[phx-value-code="#{intermediate.public_code}"])
           )

    assert has_element?(
             view,
             ~s(.puzzle-card[phx-value-code="#{advanced.public_code}"])
           )

    assert view |> element(".board-caption strong") |> render() =~ beginner.key
    assert view |> element(".board-caption .board-themes") |> render() =~ "Opposition"

    assert view |> element(~s(.puzzle-card[phx-value-code="#{beginner.public_code}"])) |> render() =~
             "Beginner"

    assert view
           |> element(~s(.puzzle-card[phx-value-code="#{intermediate.public_code}"]))
           |> render() =~ "Intermediate"

    assert view |> element(~s(.puzzle-card[phx-value-code="#{advanced.public_code}"])) |> render() =~
             "Advanced"

    assert render(view) =~ "Your move"
  end

  test "selecting a card swaps the board", %{conn: conn} do
    {_beginner, intermediate, _advanced} = curated!()
    seed_tablebase(intermediate.fen, category: :win, moves: [])

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element(~s(.puzzle-card[phx-value-code="#{intermediate.public_code}"]))
    |> render_click()

    assert has_element?(
             view,
             ~s(.puzzle-card.active[phx-value-code="#{intermediate.public_code}"])
           )

    assert view |> element(".board-caption strong") |> render() =~ intermediate.key
    assert view |> element(".board-caption .board-themes") |> render() =~ "Lucena"
    assert render(view) =~ "Your move"
  end

  test "progress CTA selects the first card", %{conn: conn} do
    {beginner, intermediate, _advanced} = curated!()
    seed_tablebase(beginner.fen, category: :win, moves: [])
    seed_tablebase(intermediate.fen, category: :win, moves: [])

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element(~s(.puzzle-card[phx-value-code="#{intermediate.public_code}"]))
    |> render_click()

    assert has_element?(
             view,
             ~s(.puzzle-card.active[phx-value-code="#{intermediate.public_code}"])
           )

    view |> element(".progress-banner a", "Begin with the basics") |> render_click()

    assert has_element?(
             view,
             ~s(.puzzle-card.active[phx-value-code="#{beginner.public_code}"])
           )
  end

  test "the board is playable from the landing page", %{conn: conn} do
    {beginner, _intermediate, _advanced} = curated!()

    seed_tablebase(beginner.fen,
      category: :win,
      moves: [%Tablebase.Move{uci: "f3f4", san: "Rf4", category: :loss, dtz: -1}]
    )

    seed_tablebase(fen_after(beginner.fen, [{{:f, 3}, {:f, 4}}]),
      category: :win,
      checkmate: true,
      moves: []
    )

    {:ok, view, _html} = live(conn, ~p"/")

    click_square(view, "f3")
    click_square(view, "f4")

    assert render(view) =~ "Solved!"
  end

  test "renders without endgames", %{conn: conn} do
    Application.put_env(:chesstrainer, :curated_endgame_codes, [])

    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "No endgames yet"
    refute has_element?(view, ".puzzle-card")
  end
end
