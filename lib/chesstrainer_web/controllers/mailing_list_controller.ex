defmodule ChesstrainerWeb.MailingListController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.MailingList
  alias Chesstrainer.MailingList.Notifier

  @return_to "/#mailing-list"
  @token_salt "mailing_list_confirm"
  @token_max_age 7 * 24 * 60 * 60

  def create(conn, %{"subscriber" => %{"email" => email}}) when is_binary(email) do
    email = String.trim(email)

    case MailingList.subscribe(email) do
      {:ok, :already_subscribed} ->
        conn
        |> put_flash(:info, "You're already on the mailing list.")
        |> redirect(to: @return_to)

      {:ok, :confirmation_required} ->
        case send_confirmation(email) do
          :ok ->
            conn
            |> put_flash(:info, "Check your inbox to confirm your subscription.")
            |> redirect(to: @return_to)

          :error ->
            conn
            |> put_flash(:error, "We couldn't send the confirmation email. Please try again.")
            |> redirect(to: @return_to)
        end

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Enter a valid email address.")
        |> redirect(to: @return_to)
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Enter a valid email address.")
    |> redirect(to: @return_to)
  end

  def confirm(conn, %{"token" => token}) do
    case Phoenix.Token.verify(
           ChesstrainerWeb.Endpoint,
           @token_salt,
           token,
           max_age: @token_max_age
         ) do
      {:ok, email} ->
        confirm_subscription(conn, email)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "That confirmation link is invalid or has expired.")
        |> redirect(to: @return_to)
    end
  end

  defp confirm_subscription(conn, email) do
    case MailingList.confirm(email) do
      {:ok, _subscriber} ->
        conn
        |> put_flash(:info, "Your mailing list subscription is confirmed.")
        |> redirect(to: @return_to)

      {:error, :not_found} ->
        conn
        |> put_flash(
          :error,
          "That address is no longer on the mailing list. Please sign up again."
        )
        |> redirect(to: @return_to)
    end
  end

  defp send_confirmation(email) do
    token = Phoenix.Token.sign(ChesstrainerWeb.Endpoint, @token_salt, email)
    url = url(~p"/mailing-list/confirm/#{token}")

    case Notifier.deliver_confirmation_instructions(email, url) do
      {:ok, _email} -> :ok
      {:error, _reason} -> :error
    end
  end
end
