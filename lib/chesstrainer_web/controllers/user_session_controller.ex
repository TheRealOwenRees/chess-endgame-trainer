defmodule ChesstrainerWeb.UserSessionController do
  use ChesstrainerWeb, :controller

  alias Chesstrainer.Accounts
  alias ChesstrainerWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"email" => login, "password" => password} = user_params

    case Accounts.get_user_by_login_and_password(login, password) do
      nil ->
        # In order to prevent user enumeration attacks, don't disclose whether
        # the email or username is registered.
        conn
        |> put_flash(:error, "Invalid email, username or password")
        |> put_flash(:email, String.slice(login, 0, 160))
        |> redirect(to: ~p"/users/log-in")

      user ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user, user_params)
    end
  end

  def update_password(conn, %{"user" => user_params}) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    %{"email" => login, "password" => password} = user_params
    user = Accounts.get_user_by_login_and_password(login, password)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> put_flash(:info, "Password updated successfully!")
    |> UserAuth.log_in_user(user, user_params)
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
