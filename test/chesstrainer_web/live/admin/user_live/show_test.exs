defmodule ChesstrainerWeb.Admin.UserLive.ShowTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import Swoosh.TestAssertions

  alias Chesstrainer.Accounts

  setup :register_and_log_in_admin

  test "shows the user's identity and editable fields", %{conn: conn} do
    member = user_fixture()

    {:ok, view, html} = live(conn, ~p"/admin/users/#{member.id}")

    assert html =~ member.email
    assert html =~ member.username
    assert has_element?(view, "#admin-user-form")
    assert has_element?(view, "#send-password-reset")
    refute has_element?(view, "#resend-confirmation")
  end

  test "an admin can change a member's role and plan", %{conn: conn} do
    member = user_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{member.id}")

    html =
      view
      |> form("#admin-user-form", user: %{role: "moderator", plan: "premium"})
      |> render_submit()

    assert html =~ "User updated successfully"
    assert Accounts.get_user!(member.id).role == :moderator
    assert Accounts.get_user!(member.id).plan == :premium
  end

  test "an admin cannot promote a member through a direct event", %{conn: conn} do
    member = user_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{member.id}")

    html = render_click(view, "save", %{"user" => %{"role" => "admin"}})

    assert html =~ "You are not authorized to modify this user."
    assert Accounts.get_user!(member.id).role == :member
  end

  test "an admin can view themselves read-only but has no editable form", %{
    conn: conn,
    user: admin
  } do
    {:ok, view, html} = live(conn, ~p"/admin/users/#{admin.id}")

    assert html =~ "You can view this account but not change its role or plan."
    refute has_element?(view, "#admin-user-form")
  end

  test "an admin is redirected away from another admin's detail page", %{conn: conn} do
    other_admin = user_with_role(:admin)

    {:ok, _view, html} =
      live(conn, ~p"/admin/users/#{other_admin.id}")
      |> follow_redirect(conn, ~p"/admin/users")

    assert html =~ "You are not authorized to view that user."
  end

  test "a super admin can change an admin's role and plan" do
    super_admin = user_with_role(:super_admin)
    admin = user_with_role(:admin)

    conn = build_conn() |> log_in_user(super_admin)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{admin.id}")

    html =
      view
      |> form("#admin-user-form", user: %{role: "moderator", plan: "premium"})
      |> render_submit()

    assert html =~ "User updated successfully"
    assert Accounts.get_user!(admin.id).role == :moderator
    assert Accounts.get_user!(admin.id).plan == :premium
  end

  test "a super admin cannot change their own role, even through a direct event" do
    super_admin = user_with_role(:super_admin)
    conn = build_conn() |> log_in_user(super_admin)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{super_admin.id}")

    html = render_click(view, "save", %{"user" => %{"role" => "admin"}})

    assert html =~ "You cannot change your own role."
    assert Accounts.get_user!(super_admin.id).role == :super_admin
  end

  test "resends a confirmation email to an unconfirmed member", %{conn: conn} do
    member = unconfirmed_user_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{member.id}")

    html = view |> element("#resend-confirmation") |> render_click()

    assert html =~ "Confirmation email sent."
    assert_email_sent(to: member.email, subject: "Confirmation instructions")
  end

  test "sends a password reset email to a member", %{conn: conn} do
    member = user_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{member.id}")

    html = view |> element("#send-password-reset") |> render_click()

    assert html =~ "Password reset email sent."
    assert_email_sent(to: member.email, subject: "Reset password instructions")
  end

  defp user_with_role(role) do
    {:ok, user} = Accounts.update_user_role(user_fixture(), role)
    user
  end
end
