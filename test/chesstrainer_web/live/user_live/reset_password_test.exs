defmodule ChesstrainerWeb.UserLive.ResetPasswordTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import ChesstrainerWeb.CaptchaFixtures
  import Swoosh.TestAssertions

  alias Chesstrainer.Accounts

  describe "forgot password" do
    test "renders the form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password")

      assert html =~ "Forgot your password?"
      assert html =~ "Send reset instructions"
      assert html =~ "<altcha-widget"
    end

    test "sends reset instructions for a known email", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        lv
        |> render_submit("submit_email", forgot_params(user.email))
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      assert_email_sent(to: user.email, subject: "Reset password instructions")
    end

    test "renders the honeypot field", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password")

      assert html =~ ~s(id="forgot-company")
      assert html =~ ~s(name="user[company]")
    end

    test "silently accepts a honeypot submission", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        lv
        |> form("#reset_password_form",
          user: %{"email" => user.email, "company" => "spam.example"}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      refute_email_sent()
    end

    test "takes the decoy path for a malformed payload", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        lv
        |> render_submit("submit_email", %{"user" => %{}})
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      refute_email_sent()
    end

    test "does not reveal an unknown email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        lv
        |> render_submit("submit_email", forgot_params("unknown@example.com"))
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      refute_email_sent()
    end

    test "rejects a submission without a captcha solution", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      html = render_submit(lv, "submit_email", %{"user" => %{"email" => user.email}})

      assert html =~ "Please complete the verification challenge"
      refute_email_sent()
    end

    test "rejects a submission with an invalid captcha solution", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      params = %{"user" => %{"email" => user.email}, "altcha" => "not-a-real-token"}
      html = render_submit(lv, "submit_email", params)

      assert html =~ "Please complete the verification challenge"
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

    test "does not render the honeypot or captcha", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password/#{token}")

      refute html =~ "forgot-company"
      refute html =~ "<altcha-widget"
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

  defp forgot_params(email) do
    %{"user" => %{"email" => email}, "altcha" => altcha_token()}
  end
end
