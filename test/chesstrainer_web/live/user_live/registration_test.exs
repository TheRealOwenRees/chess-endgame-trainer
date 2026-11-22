defmodule ChesstrainerWeb.UserLive.RegistrationTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import ChesstrainerWeb.CaptchaFixtures
  import Swoosh.TestAssertions

  alias Chesstrainer.Accounts.User
  alias Chesstrainer.MailingList.Subscriber
  alias Chesstrainer.Repo

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Register"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders the mailing list opt-in unchecked", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Send me occasional endgame tips and site news by email"

      refute lv
             |> element("#registration_form input[name=\"user[mailing_list]\"][checked]")
             |> has_element?()
    end
  end

  describe "register user" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _lv, html} =
        lv
        |> render_submit(:save, registration_params(%{"email" => unique_user_email()}))
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               "An email with instructions for how to confirm your email address has been sent to your inbox."

      assert_email_sent(subject: "Confirmation instructions")
    end

    test "subscribes to the mailing list when the box is checked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      lv
      |> render_submit(
        :save,
        registration_params(%{"email" => email, "mailing_list" => "true"})
      )

      subscriber = Repo.get_by(Subscriber, email: email)
      assert subscriber
      assert subscriber.confirmed_at == nil
    end

    test "silently accepts a honeypot submission", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _lv, html} =
        lv
        |> render_submit(:save, registration_params(%{"company" => "spam.example"}))
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               "An email with instructions for how to confirm your email address has been sent to your inbox."

      refute_email_sent()
      assert Repo.aggregate(User, :count) == 0
    end

    test "does not subscribe when the box is unchecked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> render_submit(:save, registration_params())

      assert Repo.aggregate(Subscriber, :count) == 0
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        render_submit(lv, :save, registration_params(%{"email" => user.email}))

      assert result =~ "has already been taken"
    end

    test "renders errors for duplicated username", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture()

      result =
        render_submit(lv, :save, registration_params(%{"username" => user.username}))

      assert result =~ "has already been taken"
    end

    test "renders errors for mismatched passwords", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        render_submit(
          lv,
          :save,
          registration_params(%{"password_confirmation" => "something else"})
        )

      assert result =~ "does not match password"
    end

    test "rejects a submission without a captcha solution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> render_submit(:save, Map.delete(registration_params(), "altcha"))

      assert result =~ "Please complete the verification challenge"
      assert Repo.aggregate(User, :count) == 0
    end

    test "rejects a submission with an invalid captcha solution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      params = Map.put(registration_params(), "altcha", "not-a-real-token")

      result = render_submit(lv, :save, params)

      assert result =~ "Please complete the verification challenge"
      assert Repo.aggregate(User, :count) == 0
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end

  defp registration_params(user_attrs \\ %{}) do
    user =
      Map.merge(
        %{
          "username" => unique_username(),
          "email" => unique_user_email(),
          "password" => valid_user_password(),
          "password_confirmation" => valid_user_password()
        },
        user_attrs
      )

    %{"user" => user, "altcha" => altcha_token()}
  end
end
