defmodule ChesstrainerWeb.EndgameLive.ImportTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Repo

  @krk "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"
  @mate "7k/6Q1/5K2/8/8/8/8/8 b - - 0 1"
  @six_pieces "4k2r/8/8/8/8/8/8/R2QK2R w - - 0 1"

  setup :register_and_log_in_admin

  test "shows the local tablebase status", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/endgames/import")

    assert html =~ "Local Syzygy tablebase ready"
  end

  test "looks up FENs and imports the selected ones", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/import")

    view
    |> form("#endgame-import-form", %{fens: @krk, rating: "1700"})
    |> render_submit()

    html = render_async(view, 5_000)

    assert html =~ "Ready"
    assert html =~ "KR v K"
    assert html =~ "win"

    view
    |> element("#theme-picker input[name='theme_search']")
    |> render_change(%{theme_search: "Luc"})

    view |> element("button", "Lucena") |> render_click()

    view |> element("button", "Import 1 endgame(s)") |> render_click()

    assert_redirect(view, ~p"/admin/endgames")

    endgame = Repo.get_by!(Endgame, fen: @krk) |> Repo.preload(:themes)

    assert endgame.rating == 1700.0
    assert endgame.result == :win
    assert endgame.color == :white
    assert [%{id: theme_id}] = endgame.themes
    assert theme_id == theme.id
  end

  test "explains why lines cannot be imported", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/endgames/import")

    view
    |> form("#endgame-import-form", %{
      fens: "#{@six_pieces}\nnot a fen\n#{@mate}",
      rating: "1500"
    })
    |> render_submit()

    html = render_async(view, 5_000)

    assert html =~ "Too many pieces"
    assert html =~ "Invalid FEN"
    assert html =~ "Terminal"
    refute html =~ "Import 1 endgame(s)"
  end

  test "does not import when every line is a duplicate", %{conn: conn} do
    {:ok, _endgame} = Endgames.create_endgame(%{fen: @krk, color: :white, result: :win})

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/import")

    view
    |> form("#endgame-import-form", %{fens: @krk, rating: "1500"})
    |> render_submit()

    html = render_async(view, 5_000)

    assert html =~ "Duplicate"
    assert html =~ "FEN already exists"
    assert html =~ "Import 0 endgame(s)"
  end

  test "warns when the local tablebase is not configured", %{conn: conn} do
    previous = Application.get_env(:chesstrainer, :tablebase_path)
    on_exit(fn -> Application.put_env(:chesstrainer, :tablebase_path, previous) end)

    Application.put_env(:chesstrainer, :tablebase_path, nil)

    {:ok, _view, html} = live(conn, ~p"/admin/endgames/import")

    assert html =~ "Local tablebase is not configured"
  end
end
