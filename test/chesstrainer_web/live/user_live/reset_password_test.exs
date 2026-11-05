defmodule ChesstrainerWeb.UserLive.ResetPasswordTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import Swoosh.TestAssertions

  alias Chesstrainer.Accounts

  describe "forgot password" do
    test "renders the form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password")

      assert html =~ "Forgot your password?"
      assert html =~ "Send reset instructions"
    end

    test "sends reset instructions for a known email", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      form = form(lv, "#reset_password_form", user: %{"email" => user.email})

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      assert_email_sent(to: user.email, subject: "Reset password instructions")
    end

    test "does not reveal an unknown email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      form = form(lv, "#reset_password_form", user: %{"email" => "unknown@example.com"})

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      refute_email_sent()
    end
  end

  describe "reset password" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "renders the form with a valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password/#{token}")

      assert html =~ "Reset password"
      assert html =~ "Confirm new password"
    end

    test "redirects with an error for an invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/reset-password/oops")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Reset password link is invalid or it has expired."
    end

    test "resets the password and redirects to log in", %{conn: conn, user: user, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      form =
        form(lv, "#reset_password_form",
          user: %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        )

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Password reset successfully"

      assert Accounts.get_user_by_login_and_password(user.email, "new valid password")
    end

    test "shows validation errors for mismatched passwords", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      html =
        lv
        |> form("#reset_password_form",
          user: %{
            "password" => "new valid password",
            "password_confirmation" => "something else"
          }
        )
        |> render_submit()

      assert html =~ "does not match password"
    end
  end
end
