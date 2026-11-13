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
        |> put_flash(
          :error,
          "That confirmation link is invalid or has expired. Log in to request a new one."
        )
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
