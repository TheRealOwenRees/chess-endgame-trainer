defmodule ChesstrainerWeb.UserConfirmationController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Accounts
  alias Chesstrainer.MailingList

  def edit(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, user} ->
        MailingList.confirm_user_subscription(user)

        conn
        |> put_flash(:info, "User confirmed successfully.")
        |> redirect(to: ~p"/users/log-in")

      :error ->
        conn
        |> put_flash(:error, "User not found or token is invalid.")
        |> redirect(to: ~p"/users/register")
    end
  end
end
