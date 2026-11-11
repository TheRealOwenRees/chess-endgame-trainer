defmodule ChesstrainerWeb.UserSessionController do
  use ChesstrainerWeb, :controller

  require Logger

  alias Chesstrainer.Accounts
  alias ChesstrainerWeb.ClientAddress
  alias ChesstrainerWeb.LoginThrottle
  alias ChesstrainerWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    authenticate(conn, user_params, ~p"/users/log-in", nil)
  end

  def create_admin(conn, %{"user" => user_params}) do
    if ChesstrainerWeb.prelaunch?() do
      authenticate(conn, user_params, ~p"/admin/log-in", ~p"/admin/endgames")
    else
      authenticate(conn, user_params, ~p"/users/log-in", nil)
    end
  end

  defp authenticate(conn, user_params, failure_path, success_path) do
    %{"email" => login} = user_params
    address = ClientAddress.from_conn(conn)

    case LoginThrottle.check(address, login) do
      :ok ->
        attempt_login(conn, address, user_params, failure_path, success_path)

      {:throttled, bucket, retry_in_ms} ->
        log_auth_event("auth.login.throttled", address, reason: bucket)

        conn
        |> put_flash(:error, throttle_message(retry_in_ms))
        |> redirect(to: failure_path)
    end
  end

  defp attempt_login(conn, address, user_params, failure_path, success_path) do
    %{"email" => login, "password" => password} = user_params

    case Accounts.get_user_by_login_and_password(login, password) do
      nil ->
        authentication_failed(conn, address, login, :invalid_credentials, failure_path)

      user ->
        if user.confirmed_at do
          LoginThrottle.record_success(login)

          conn
          |> maybe_put_return_to(success_path)
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
        else
          maybe_resend_confirmation(user, login)
          authentication_failed(conn, address, login, :unconfirmed, failure_path)
        end
    end
  end

  defp maybe_resend_confirmation(user, login) do
    if LoginThrottle.claim_confirmation_resend(login) do
      case Accounts.deliver_user_confirmation_instructions(
             user,
             &url(~p"/users/confirm/#{&1}")
           ) do
        {:ok, _email} -> :ok
        {:error, _reason} -> Logger.warning("auth.confirmation.resend_failed")
      end
    end

    :ok
  end

  defp authentication_failed(conn, address, login, reason, failure_path) do
    LoginThrottle.record_failure(address, login)
    log_auth_event("auth.login.failed", address, reason: reason)

    # In order to prevent user enumeration attacks, report the same error as
    # invalid credentials.
    invalid_credentials(conn, login, failure_path)
  end

  defp log_auth_event(message, address, metadata) do
    Logger.warning(message, Keyword.put(metadata, :ip, LoginThrottle.fingerprint(address)))
  end

  defp throttle_message(retry_in_ms) do
    minutes = max(div(retry_in_ms + 59_999, 60_000), 1)
    unit = if minutes == 1, do: "minute", else: "minutes"

    "Too many attempts. Try again in #{minutes} #{unit}."
  end

  defp invalid_credentials(conn, login, path) do
    conn
    |> put_flash(:error, "Invalid email, username or password")
    |> put_flash(:email, String.slice(login, 0, 160))
    |> redirect(to: path)
  end

  defp maybe_put_return_to(conn, nil), do: conn
  defp maybe_put_return_to(conn, path), do: put_session(conn, :user_return_to, path)

  def update_password(conn, %{"user" => user_params}) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    %{"email" => login, "password" => password} = user_params
    user = Accounts.get_user_by_login_and_password(login, password)

    conn
    |> put_session(:user_return_to, ~p"/users/profile")
    |> put_flash(:info, "Password updated successfully!")
    |> UserAuth.log_in_user(user, user_params)
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
