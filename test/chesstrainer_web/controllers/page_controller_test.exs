defmodule ChesstrainerWeb.PageControllerTest do
  use ChesstrainerWeb.ConnCase

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Themes

  @fen "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"

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

  test "GET / renders a random endgame board and its theme", %{conn: conn} do
    {:ok, theme} = Themes.create_theme(%{name: "Opposition", category: :endgame})

    {:ok, endgame} =
      Endgames.create_endgame(
        %{fen: @fen, color: :white, result: :win, rating: 1500},
        [theme]
      )

    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ endgame.key
    assert html =~ "Opposition"
    assert html =~ "To move"
    assert html =~ "White"
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
end
