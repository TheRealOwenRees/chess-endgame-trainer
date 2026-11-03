defmodule Chesstrainer.Accounts.Role do
  @moduledoc """
  The ordered authority tiers a user can hold.

  A higher rank may do everything a lower rank may, so authorization checks
  should ask for the minimum tier they need via `at_least?/2`.
  """

  @values [:member, :moderator, :admin, :super_admin]

  @ranks %{
    member: 0,
    moderator: 1,
    admin: 2,
    super_admin: 3
  }

  @doc "All roles, ordered from least to most authority."
  def values, do: @values

  @doc "The numeric rank of a role."
  def rank(role) when role in @values, do: Map.fetch!(@ranks, role)

  @doc """
  Returns true when `role` is at least as authoritative as `minimum`.

  A missing role (no user) never satisfies any minimum.
  """
  def at_least?(role, minimum) when role in @values and minimum in @values do
    rank(role) >= rank(minimum)
  end

  def at_least?(_role, _minimum), do: false

  @doc "Returns true when the role may use the admin area."
  def admin?(role), do: at_least?(role, :admin)
end
