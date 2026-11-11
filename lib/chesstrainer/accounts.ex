defmodule Chesstrainer.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Chesstrainer.Repo

  alias Chesstrainer.Accounts.{Policy, Role, Scope, User, UserToken, UserNotifier}
  alias Chesstrainer.MailingList

  @admin_users_per_page 25

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email or username.

  Email and username are both `citext`, so the lookup ignores case.

  ## Examples

      iex> get_user_by_login("foo@example.com")
      %User{}

      iex> get_user_by_login("unknown")
      nil

  """
  def get_user_by_login(login) when is_binary(login) do
    login = String.trim(login)

    from(u in User, where: u.email == ^login or u.username == ^login, limit: 1)
    |> Repo.one()
  end

  @doc """
  Gets a user by email or username and password.

  ## Examples

      iex> get_user_by_login_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_login_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_login_and_password(login, password)
      when is_binary(login) and is_binary(password) do
    user = get_user_by_login(login)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes.

  See `Chesstrainer.Accounts.User.registration_changeset/3`.
  """
  def change_user_registration(user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed and the token is
  deleted. The token is valid for one day.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_confirmation_token_query(token),
         %UserToken{sent_to: email} <- Repo.one(query),
         %User{} = user <- Repo.get_by(User, email: email),
         {:ok, user} <- Repo.update(User.confirm_changeset(user)),
         {_count, _result} <-
           Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: "confirm"])) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  @doc """
  Updates a user's authority role.

  This is the only supported path for changing roles; registration never casts
  `role`, so a user cannot promote themselves.
  """
  def update_user_role(%User{} = user, role) do
    user
    |> User.role_changeset(%{role: role})
    |> Repo.update()
  end

  ## Admin user management

  @doc """
  Returns a page of users the scope may administer, newest first.

  Options:

    * `:search` - case-insensitive match on email or username
    * `:page` - 1-based page number (defaults to 1)
    * `:per_page` - page size (defaults to 25, capped at 100)

  Admins only see members and moderators; super admins see every role.
  Returns `{:error, :unauthorized}` when the scope lacks user management.
  """
  def list_users_for_admin(scope, opts \\ []) do
    with :ok <- ensure_manage_users(scope) do
      page = normalize_page(Keyword.get(opts, :page, 1))
      per_page = normalize_per_page(Keyword.get(opts, :per_page, @admin_users_per_page))
      offset = (page - 1) * per_page

      users =
        scope
        |> admin_users_query(opts)
        |> order_by([u], desc: u.inserted_at, desc: u.id)
        |> limit(^per_page)
        |> offset(^offset)
        |> Repo.all()

      {:ok, users}
    end
  end

  @doc """
  Counts the users visible to the scope, using the same filters as
  `list_users_for_admin/2`.
  """
  def count_users_for_admin(scope, opts \\ []) do
    with :ok <- ensure_manage_users(scope) do
      count =
        scope
        |> admin_users_query(opts)
        |> select([u], count(u.id))
        |> Repo.one()

      {:ok, count}
    end
  end

  @doc """
  Fetches a user for the admin detail page.

  Returns `{:error, :unauthorized}` when the scope may not view the target and
  `{:error, :not_found}` for an unknown id.
  """
  def get_user_for_admin(scope, id) do
    with :ok <- ensure_manage_users(scope) do
      case fetch_user(id) do
        nil ->
          {:error, :not_found}

        %User{} = user ->
          if Policy.can_view_user?(scope, user) do
            {:ok, user}
          else
            {:error, :unauthorized}
          end
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for the admin-editable fields (role and plan).
  """
  def change_user_as_admin(%User{} = user, attrs \\ %{}) do
    User.admin_changeset(user, attrs)
  end

  @doc """
  Updates a user's role and plan after enforcing the admin capability matrix.

  The last-super-admin check runs inside the update transaction with a row lock,
  so concurrent demotions cannot remove the final super admin.

  Returns `{:error, :unauthorized}`, `{:error, :own_role}`,
  `{:error, :last_super_admin}` or `{:error, %Ecto.Changeset{}}` instead of
  raising.
  """
  def update_user_as_admin(scope, %User{} = user, attrs) do
    changeset = User.admin_changeset(user, attrs)
    role_change = Ecto.Changeset.get_change(changeset, :role)

    with :ok <- ensure_manage_users(scope),
         :ok <- ensure_not_own_role_change(scope, user, role_change),
         :ok <- ensure_can_manage_user(scope, user),
         :ok <- ensure_can_assign_role(scope, role_change),
         {:ok, updated} <- persist_user_changes(user, changeset) do
      log_user_update(scope, user, changeset)
      {:ok, updated}
    end
  end

  @doc """
  Creates an invitation and emails the recipient a link to choose a password.

  The account is confirmed but has no password until the invitee follows the
  link. `invite_url_fun` receives the encoded token and must return a URL.
  """
  def invite_user_as_admin(scope, attrs, invite_url_fun)
      when is_function(invite_url_fun, 1) do
    role = normalize_role(role_param(attrs) || :member)

    with :ok <- ensure_manage_users(scope),
         :ok <- ensure_can_assign_role(scope, role) do
      changeset =
        %User{}
        |> User.invite_changeset(attrs)
        |> User.admin_changeset(attrs)

      case Repo.insert(changeset) do
        {:ok, user} ->
          Logger.info("admin.user.invited",
            actor_id: scope.user.id,
            target_id: user.id,
            fields: [:invite]
          )

          case deliver_invite_instructions(user, invite_url_fun) do
            {:ok, _email} -> {:ok, user}
            {:error, reason} -> {:error, reason}
          end

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Sends a password-reset email on behalf of an administrator.

  Uses the same policy as the editable user screen: an admin cannot trigger a
  reset for another admin or a super admin.
  """
  def send_user_reset_password_instructions_as_admin(scope, %User{} = user, reset_url_fun)
      when is_function(reset_url_fun, 1) do
    with :ok <- ensure_manage_users(scope),
         :ok <- ensure_can_manage_user(scope, user) do
      case deliver_user_reset_password_instructions(user, reset_url_fun) do
        {:ok, email} ->
          Logger.info("admin.user.password_reset_sent",
            actor_id: scope.user.id,
            target_id: user.id
          )

          {:ok, email}

        error ->
          error
      end
    end
  end

  @doc """
  Resends the account-confirmation email on behalf of an administrator.
  """
  def resend_user_confirmation_instructions_as_admin(scope, %User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    with :ok <- ensure_manage_users(scope),
         :ok <- ensure_can_manage_user(scope, user) do
      case deliver_user_confirmation_instructions(user, confirmation_url_fun) do
        {:ok, email} ->
          Logger.info("admin.user.confirmation_resent",
            actor_id: scope.user.id,
            target_id: user.id
          )

          {:ok, email}

        error ->
          error
      end
    end
  end

  defp admin_users_query(scope, opts) do
    roles = Policy.visible_roles(scope)
    search = opts |> Keyword.get(:search, "") |> to_string() |> String.trim()

    query = from(u in User, where: u.role in ^roles)

    if search == "" do
      query
    else
      pattern = "%#{search}%"

      where(
        query,
        [u],
        ilike(u.email, ^pattern) or ilike(u.username, ^pattern)
      )
    end
  end

  defp persist_user_changes(user, changeset) do
    Repo.transact(fn ->
      with :ok <- ensure_not_last_super_admin(user, changeset),
           {:ok, updated} <- Repo.update(changeset) do
        {:ok, updated}
      end
    end)
  end

  defp ensure_not_last_super_admin(%User{role: :super_admin}, changeset) do
    case Ecto.Changeset.get_change(changeset, :role) do
      role when role in [nil, :super_admin] ->
        :ok

      _role ->
        super_admins =
          Repo.all(from(u in User, where: u.role == :super_admin, lock: "FOR UPDATE"))

        if length(super_admins) <= 1 do
          {:error, :last_super_admin}
        else
          :ok
        end
    end
  end

  defp ensure_not_last_super_admin(_user, _changeset), do: :ok

  defp log_user_update(scope, user, changeset) do
    fields = changeset.changes |> Map.keys() |> Enum.sort()

    if fields != [] do
      Logger.info("admin.user.updated",
        actor_id: scope.user.id,
        target_id: user.id,
        fields: fields
      )
    end
  end

  defp deliver_invite_instructions(user, invite_url_fun) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_invite_instructions(user, invite_url_fun.(encoded_token))
  end

  defp ensure_manage_users(scope) do
    if Policy.can?(scope, :manage_users), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_can_manage_user(scope, user) do
    if Policy.can_manage_user?(scope, user), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_can_assign_role(_scope, nil), do: :ok

  defp ensure_can_assign_role(scope, role) do
    if Policy.can_assign_role?(scope, role), do: :ok, else: {:error, :unauthorized}
  end

  defp ensure_not_own_role_change(%Scope{user: %User{id: id}}, %User{id: id}, role)
       when not is_nil(role),
       do: {:error, :own_role}

  defp ensure_not_own_role_change(_scope, _user, _role), do: :ok

  defp fetch_user(id) do
    Repo.get(User, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp role_param(attrs), do: Map.get(attrs, "role") || Map.get(attrs, :role)

  defp normalize_role(role) do
    cond do
      role in Role.values() -> role
      is_binary(role) -> Enum.find(Role.values(), &(Atom.to_string(&1) == role))
      true -> nil
    end
  end

  defp normalize_page(page) when is_integer(page) and page > 0, do: page

  defp normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {number, ""} when number > 0 -> number
      _ -> 1
    end
  end

  defp normalize_page(_page), do: 1

  defp normalize_per_page(per_page) when is_integer(per_page) and per_page > 0 do
    min(per_page, 100)
  end

  defp normalize_per_page(_per_page), do: @admin_users_per_page

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Chesstrainer.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {:ok, _subscription} <- MailingList.update_subscriber_email(user, email),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Chesstrainer.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  @doc ~S"""
  Delivers the reset password email instructions to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset-password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user with the given reset password token.

  Returns `nil` if the token is invalid or has expired.
  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_reset_password_token_query(token),
         %UserToken{sent_to: email} <- Repo.one(query),
         %User{} = user <- Repo.get_by(User, email: email) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.
  """
  def reset_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Deletion

  @doc """
  Permanently deletes a user and all of their data.

  Attempts and session tokens are removed by database cascades. There is no
  soft delete and no way to recover the account.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Returns the number of users with at least one valid session token.

  Session tokens stay valid for `UserToken.session_validity_in_days/0` days, so
  this counts users who logged in during that window, not necessarily users who
  are connected right now. A user with multiple sessions counts once.
  """
  def count_logged_in_users do
    days = UserToken.session_validity_in_days()

    UserToken
    |> where([t], t.context == "session" and t.inserted_at > ago(^days, "day"))
    |> select([t], count(t.user_id, :distinct))
    |> Repo.one()
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
