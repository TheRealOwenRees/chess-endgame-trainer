defmodule ChesstrainerWeb.Plugs.PrelaunchTest do
  use ChesstrainerWeb.ConnCase, async: false

  import Chesstrainer.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Repo

  setup do
    previous = Application.get_env(:chesstrainer, :prelaunch)
    on_exit(fn -> restore_env(:prelaunch, previous) end)
    Application.put_env(:chesstrainer, :prelaunch, true)
    :ok
  end

  test "allows the public pages, legal pages, health, and admin login", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200)
    assert conn |> get(~p"/privacy") |> html_response(200)
    assert conn |> get(~p"/terms-conditions") |> html_response(200)
    assert conn |> get(~p"/health") |> response(200)
    assert conn |> get(~p"/admin/log-in") |> html_response(200)
  end

  test "hides public auth links and start training", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    refute html =~ ">Log in<"
    refute html =~ ">Register<"
    refute html =~ "Start training"
  end

  test "the hidden admin login uses the admin form action", %{conn: conn} do
    html = conn |> get(~p"/admin/log-in") |> html_response(200)

    assert html =~ ~s(action="/admin/log-in")
    refute html =~ "Sign up"
  end

  test "pauses the public login route", %{conn: conn} do
    assert conn |> get(~p"/users/log-in") |> redirected_to() == "/"
  end

  test "admin login redirects to the admin area", %{conn: conn} do
    user =
      user_fixture()
      |> Ecto.Changeset.change(role: :admin)
      |> Repo.update!()

    conn =
      post(conn, ~p"/admin/log-in",
        user: %{email: user.email, password: "hello world!", remember_me: "true"}
      )

    assert redirected_to(conn) == "/admin/endgames"
  end

  test "redirects blocked routes to the home page", %{conn: conn} do
    conn = get(conn, ~p"/train")

    assert redirected_to(conn) == "/"
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
  end

  test "allows the admin bulk import page", %{conn: conn} do
    admin =
      user_fixture()
      |> Ecto.Changeset.change(role: :admin)
      |> Repo.update!()

    conn = log_in_user(conn, admin)

    assert {:ok, _view, html} = live(conn, ~p"/admin/endgames/import")
    assert html =~ "Import endgames"
  end

  test "redirects registration and unknown pages", %{conn: conn} do
    assert conn |> get(~p"/users/register") |> redirected_to() == "/"
    assert conn |> get("/definitely-not-a-page") |> redirected_to() == "/"
  end

  test "blocks direct registration LiveView requests", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users/register")
  end

  test "blocks registration reached through LiveView navigation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/log-in")

    assert {:error, {:redirect, %{to: "/"}}} =
             live_redirect(view, to: ~p"/users/register")

    assert Repo.aggregate(User, :count) == 0
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
