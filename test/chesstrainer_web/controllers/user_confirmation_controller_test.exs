defmodule ChesstrainerWeb.UserConfirmationControllerTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.User
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
               "User not found or token is invalid."

      assert redirected_to(conn) == ~p"/users/register"
    end
  end
end
