defmodule Chesstrainer.Accounts.Policy do
  @moduledoc """
  The single source of truth for administrator capabilities.

  Roles are ordered by `Chesstrainer.Accounts.Role`. An administrator may only
  manage users below their own rank; a `super_admin` may also manage admins and
  other super admins, but never changes their own role.

  The router uses `can?/2` to gate the admin area, and every mutating admin
  LiveView calls back into this module or into the scoped `Accounts` functions
  so hidden buttons are never the only protection.
  """

  alias Chesstrainer.Accounts.{Role, Scope, User}

  @capabilities %{
    manage_endgames: [:admin, :super_admin],
    manage_themes: [:admin, :super_admin],
    manage_users: [:admin, :super_admin]
  }

  @doc "All admin capabilities."
  @spec capabilities() :: [atom()]
  def capabilities, do: Map.keys(@capabilities)

  @doc """
  Returns true when the scope may perform the given admin capability.

  A nil scope or a member/moderator never satisfies an admin capability.
  """
  @spec can?(Scope.t() | nil, atom()) :: boolean()
  def can?(%Scope{user: %User{role: role}}, capability) when is_atom(capability) do
    role in Map.get(@capabilities, capability, [])
  end

  def can?(_scope, _capability), do: false

  @doc """
  Returns true when the scope may edit the target user's role and plan.

  An actor may only modify a user whose role rank is strictly lower, except a
  `super_admin`, who may also modify admins and other super admins. Nobody may
  modify themselves through the admin area.
  """
  @spec can_manage_user?(Scope.t() | nil, User.t()) :: boolean()
  def can_manage_user?(%Scope{user: %User{} = actor} = scope, %User{} = target) do
    cond do
      not can?(scope, :manage_users) -> false
      actor.id == target.id -> false
      actor.role == :super_admin -> true
      Role.rank(actor.role) > Role.rank(target.role) -> true
      true -> false
    end
  end

  def can_manage_user?(_scope, _target), do: false

  @doc """
  Returns true when the scope may view the target user in the admin area.

  Admins can see themselves and lower-ranked users read-only; super admins can
  see everyone. This is deliberately wider than `can_manage_user?/2`, which
  controls the editable form.
  """
  @spec can_view_user?(Scope.t() | nil, User.t()) :: boolean()
  def can_view_user?(%Scope{user: %User{} = actor} = scope, %User{} = target) do
    can?(scope, :manage_users) and
      (actor.id == target.id or actor.role == :super_admin or
         Role.rank(actor.role) > Role.rank(target.role))
  end

  def can_view_user?(_scope, _target), do: false

  @doc """
  Returns true when the scope may assign the given role.

  Admins can only assign member or moderator. Super admins can assign any role.
  """
  @spec can_assign_role?(Scope.t() | nil, Role.value()) :: boolean()
  def can_assign_role?(%Scope{user: %User{role: :super_admin}}, role) do
    role in Role.values()
  end

  def can_assign_role?(%Scope{user: %User{role: actor_role}}, role) do
    role in Role.values() and Role.rank(actor_role) > Role.rank(role)
  end

  def can_assign_role?(_scope, _role), do: false

  @doc """
  Returns the roles whose users the scope may see in the admin user list.

  Admins only see members and moderators; super admins see every role.
  """
  @spec visible_roles(Scope.t() | nil) :: [Role.value()]
  def visible_roles(%Scope{user: %User{role: :super_admin}}), do: Role.values()

  def visible_roles(%Scope{user: %User{role: :admin}}), do: [:member, :moderator]
  def visible_roles(_scope), do: []
end
