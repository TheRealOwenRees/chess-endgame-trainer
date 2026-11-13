defmodule ChesstrainerWeb.UserConfirmationControllerTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.MailingList
  alias Chesstrainer.MailingList.Subscriber
  alias Chesstrainer.Repo

  setup do
    %{user: unconfirmed_user_fixture()}
  end

  describe "GET /users/confirm/:token" do
    test "confirms the user and redirects to the login page", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/confirm/#{token}")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "User confirmed successfully."
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Repo.get!(User, user.id).confirmed_at
    end

    test "redirects with an error for an invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/confirm/oops")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "That confirmation link is invalid or has expired. Log in to request a new one."

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "confirms a linked mailing-list opt-in", %{conn: conn, user: user} do
      {:ok, _subscriber} = MailingList.subscribe_user(user)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      get(conn, ~p"/users/confirm/#{token}")

      assert %Subscriber{confirmed_at: confirmed_at} =
               Repo.get_by(Subscriber, user_id: user.id)

      assert confirmed_at
    end
  end
end
