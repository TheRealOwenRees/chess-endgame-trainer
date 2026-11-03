defmodule ChesstrainerWeb.AdminGatingTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Accounts

  test "unauthenticated visitors are redirected to log in", %{conn: conn} do
    conn = get(conn, ~p"/admin/endgames")

    assert redirected_to(conn) == ~p"/users/log-in"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "members are redirected home", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/admin/endgames")

    assert redirected_to(conn) == ~p"/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You are not authorized to access this page."
  end

  test "moderators are redirected home", %{conn: conn} do
    {:ok, user} = Accounts.update_user_role(user_fixture(), :moderator)

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/admin/endgames")

    assert redirected_to(conn) == ~p"/"
  end

  test "admins are admitted", %{conn: conn} do
    {:ok, user} = Accounts.update_user_role(user_fixture(), :admin)

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/admin/endgames")

    assert html_response(conn, 200)
  end

  test "super admins are admitted", %{conn: conn} do
    {:ok, user} = Accounts.update_user_role(user_fixture(), :super_admin)

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/admin/endgames")

    assert html_response(conn, 200)
  end

  test "the navbar hides the Admin link from members", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")

    refute html_response(conn, 200) =~ ~p"/admin/endgames"
  end

  test "the navbar shows the Admin link to admins", %{conn: conn} do
    {:ok, user} = Accounts.update_user_role(user_fixture(), :admin)

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert html_response(conn, 200) =~ ~p"/admin/endgames"
  end
end
