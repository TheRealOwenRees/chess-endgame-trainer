defmodule ChesstrainerWeb.UserLive.ProfileTest do
  use ChesstrainerWeb.ConnCase, async: true

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.MailingList
  alias Chesstrainer.MailingList.Subscriber
  alias Chesstrainer.Repo
  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  describe "profile sections" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "links to the account, settings and data tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile")

      assert has_element?(view, "#profile-tabs")
      assert has_element?(view, ~s{a#profile-tab-account[href="/users/profile"]})
      assert has_element?(view, ~s{a#profile-tab-settings[href="/users/profile/settings"]})
      assert has_element?(view, ~s{a#profile-tab-data[href="/users/profile/data"]})
    end

    test "settings tab shows the current plan", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/profile/settings")

      assert has_element?(view, "#membership-settings")
      assert html =~ "Free"
    end

    test "data tab shows progress, export links and recent attempts", %{conn: conn, user: user} do
      endgame = endgame_fixture()
      {:ok, _attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      {:ok, view, html} = live(conn, ~p"/users/profile/data")

      assert has_element?(view, "#training-stats")
      assert html =~ "100%"
      assert html =~ endgame.key
      assert has_element?(view, ~s{a#export-csv[href="/users/profile/export/csv"]})
      assert has_element?(view, ~s{a#export-json[href="/users/profile/export/json"]})
    end

    test "data tab shows an empty state without attempts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/profile/data")

      assert render(view) =~ "No attempts yet"
    end

    test "data tab does not require sudo mode", %{conn: conn, user: user} do
      conn =
        log_in_user(conn, user,
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )

      {:ok, view, _html} = live(conn, ~p"/users/profile/data")

      assert has_element?(view, "#training-stats")
    end
  end

  describe "Account tab" do
    test "renders the account forms", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/profile")

      assert html =~ "Change Email"
      assert html =~ "Save Password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/profile")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user password", %{conn: conn, user: user} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/profile"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_login_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "delete account" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the permanent deletion warning", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/profile")

      assert html =~ "Delete account"
      assert html =~ "permanent and cannot be undone"
      assert html =~ "Nothing can be recovered"
    end

    test "deletes the user and redirects home", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      assert {:error, {:redirect, %{to: "/"}}} =
               result = lv |> element("#delete_account_button") |> render_click()

      refute Accounts.get_user_by_email(user.email)

      {:ok, conn} = follow_redirect(result, conn, ~p"/")
      assert conn.resp_body =~ "Your account has been deleted."
    end

    test "logs the deleted user out", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      lv |> element("#delete_account_button") |> render_click()

      assert {:error, redirect} = live(conn, ~p"/users/profile")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
      refute Accounts.get_user_by_email(user.email)
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/profile"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/profile"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/profile"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end

  describe "mailing list settings" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows the not-subscribed state", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/profile/settings")

      assert has_element?(view, "#mailing-list-settings")
      assert html =~ "not subscribed"
      refute has_element?(view, "#unsubscribe-mailing-list")
    end

    test "unsubscribes a subscribed user", %{conn: conn, user: user} do
      {:ok, _subscriber} = MailingList.subscribe_user(user)
      MailingList.confirm_user_subscription(user)

      {:ok, view, _html} = live(conn, ~p"/users/profile/settings")

      assert has_element?(view, "#unsubscribe-mailing-list")

      html = view |> element("#unsubscribe-mailing-list") |> render_click()

      assert html =~ "removed from the mailing list"
      refute has_element?(view, "#unsubscribe-mailing-list")

      assert %Subscriber{unsubscribed_at: unsubscribed_at} =
               Repo.get_by(Subscriber, user_id: user.id)

      assert unsubscribed_at
    end
  end
end
