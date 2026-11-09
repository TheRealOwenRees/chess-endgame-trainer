defmodule ChesstrainerWeb.MailingListController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.MailingList
  alias Chesstrainer.MailingList.Notifier
  alias ChesstrainerWeb.MailingListFormToken

  @return_to "/#mailing-list"
  @token_salt "mailing_list_confirm"
  @token_max_age 7 * 24 * 60 * 60

  def create(conn, %{"subscriber" => params}) when is_map(params) do
    if mailing_list_enabled?() do
      create_subscription(conn, params)
    else
      closed(conn)
    end
  end

  def create(conn, _params) do
    if mailing_list_enabled?(), do: invalid_email(conn), else: closed(conn)
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

  defp create_subscription(conn, params) do
    email = params["email"]

    cond do
      honeypot_filled?(params) ->
        fake_success(conn)

      not is_binary(email) ->
        invalid_email(conn)

      MailingListFormToken.verify(params["form_token"]) != :ok ->
        form_error(conn)

      true ->
        subscribe(conn, email)
    end
  end

  defp subscribe(conn, email) do
    email = String.trim(email)

    case MailingList.subscribe(email) do
      {:ok, :already_subscribed} ->
        conn
        |> put_flash(:info, "You're already on the mailing list.")
        |> redirect(to: @return_to)

      {:ok, :confirmation_required} ->
        if MailingList.confirmation_allowed?(email) do
          send_confirmation(conn, email)
        else
          fake_success(conn)
        end

      {:error, %Ecto.Changeset{}} ->
        invalid_email(conn)
    end
  end

  defp send_confirmation(conn, email) do
    token = Phoenix.Token.sign(ChesstrainerWeb.Endpoint, @token_salt, email)
    url = url(~p"/mailing-list/confirm/#{token}")

    case Notifier.deliver_confirmation_instructions(email, url) do
      {:ok, _email} ->
        _ = MailingList.mark_confirmation_sent(email)

        conn
        |> put_flash(:info, "Check your inbox to confirm your subscription.")
        |> redirect(to: @return_to)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "We couldn't send the confirmation email. Please try again.")
        |> redirect(to: @return_to)
    end
  end

  defp honeypot_filled?(params), do: params["company"] not in [nil, ""]

  defp fake_success(conn) do
    conn
    |> put_flash(:info, "Check your inbox to confirm your subscription.")
    |> redirect(to: @return_to)
  end

  defp form_error(conn) do
    conn
    |> put_flash(:error, "Please refresh the page and try again.")
    |> redirect(to: @return_to)
  end

  defp invalid_email(conn) do
    conn
    |> put_flash(:error, "Enter a valid email address.")
    |> redirect(to: @return_to)
  end

  defp closed(conn) do
    conn
    |> put_flash(:info, "The mailing list isn't open yet.")
    |> redirect(to: @return_to)
  end

  defp mailing_list_enabled? do
    Application.get_env(:chesstrainer, :mailing_list_enabled, true)
  end
end
