defmodule ChesstrainerWeb.UserSessionController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Accounts
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
    %{"email" => login, "password" => password} = user_params

    case Accounts.get_user_by_login_and_password(login, password) do
      nil ->
        invalid_credentials(conn, login, failure_path)

      user ->
        if user.confirmed_at do
          conn
          |> maybe_put_return_to(success_path)
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
        else
          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &url(~p"/users/confirm/#{&1}")
            )

          # In order to prevent user enumeration attacks, report the same error
          # as invalid credentials.
          invalid_credentials(conn, login, failure_path)
        end
    end
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
