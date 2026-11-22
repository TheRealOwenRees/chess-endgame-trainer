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

  test "allows the public pages, legal pages, health, and login", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200)
    assert conn |> get(~p"/privacy") |> html_response(200)
    assert conn |> get(~p"/terms-conditions") |> html_response(200)
    assert conn |> get(~p"/health") |> response(200)
    assert conn |> get(~p"/users/log-in") |> html_response(200)
  end

  test "hides public auth links and start training", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    refute html =~ ">Log in<"
    refute html =~ ">Register<"
    refute html =~ "Start training"
  end

  test "the prelaunch login form posts to the public login route", %{conn: conn} do
    html = conn |> get(~p"/users/log-in") |> html_response(200)

    assert html =~ ~s(action="/users/log-in")
    refute html =~ "Sign up"
  end

  test "an admin can log in through the public login route", %{conn: conn} do
    admin =
      user_fixture()
      |> Ecto.Changeset.change(role: :admin)
      |> Repo.update!()

    conn =
      post(conn, ~p"/users/log-in",
        user: %{email: admin.email, password: "hello world!", remember_me: "true"}
      )

    assert get_session(conn, :user_token)
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
  end

  test "allows the captcha challenge endpoint", %{conn: conn} do
    conn = get(conn, "/altcha/challenge")

    assert response(conn, 200)
    assert conn |> get_resp_header("content-type") |> hd() =~ "application/json"
  end

  test "renders the captcha on the prelaunch signup form", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "<altcha-widget"
    assert html =~ ~s(challenge="/altcha/challenge")
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
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    assert {:error, {:redirect, %{to: "/"}}} =
             live_redirect(view, to: ~p"/users/register")

    assert Repo.aggregate(User, :count) == 0
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
