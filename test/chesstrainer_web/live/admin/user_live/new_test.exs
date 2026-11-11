defmodule ChesstrainerWeb.Admin.UserLive.NewTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import Swoosh.TestAssertions

  alias Chesstrainer.Accounts

  setup :register_and_log_in_admin

  test "invites a new member", %{conn: conn} do
    email = unique_user_email()
    username = unique_username()

    {:ok, view, _html} = live(conn, ~p"/admin/users/new")

    {:ok, _view, html} =
      view
      |> form("#invite-user-form", user: %{email: email, username: username, role: "member"})
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/users")

    assert html =~ "Invitation sent to #{email}."

    invited = Accounts.get_user_by_email(email)
    assert invited.username == username
    assert invited.confirmed_at

    assert_email_sent(to: email, subject: "You're invited to Inner Square Chess")
  end

  test "does not offer admin roles to an admin", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/users/new")

    html = render(view)

    assert html =~ "Moderator"
    refute html =~ ~s(value="admin")
    refute html =~ ~s(value="super_admin")
  end

  test "rejects a direct attempt to invite an admin", %{conn: conn} do
    email = unique_user_email()

    {:ok, view, _html} = live(conn, ~p"/admin/users/new")

    html =
      render_click(view, "save", %{
        "user" => %{
          "email" => email,
          "username" => unique_username(),
          "role" => "admin"
        }
      })

    assert html =~ "You are not authorized to assign that role."
    refute Accounts.get_user_by_email(email)
  end

  test "shows duplicate email errors", %{conn: conn} do
    existing = user_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/users/new")

    html =
      view
      |> form("#invite-user-form",
        user: %{
          email: existing.email,
          username: unique_username(),
          role: "member"
        }
      )
      |> render_submit()

    assert html =~ "has already been taken"
  end

  test "shows the admin sub-navigation", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/users/new")

    assert html =~ ~p"/admin/endgames"
    assert html =~ ~p"/admin/themes"
    assert html =~ ~p"/admin/users"
  end
end
