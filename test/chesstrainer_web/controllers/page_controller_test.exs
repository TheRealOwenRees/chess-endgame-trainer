defmodule ChesstrainerWeb.PageControllerTest do
  use ChesstrainerWeb.ConnCase

  import Chesstrainer.AccountsFixtures

  test "GET / renders the landing page and navbar", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "Learn to see the"
    assert html =~ "LUCID"
    assert html =~ "Method"
    assert html =~ "Puzzles"
    assert html =~ "Start training"
    assert html =~ ~s(id="nav-links")
    assert html =~ "menu-button"
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
