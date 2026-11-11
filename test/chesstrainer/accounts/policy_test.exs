defmodule Chesstrainer.Accounts.PolicyTest do
  use Chesstrainer.DataCase, async: true

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Accounts.Scope

  describe "can?/2" do
    test "members and moderators have no admin capabilities" do
      for role <- [:member, :moderator], capability <- Policy.capabilities() do
        refute Policy.can?(scope_for(role), capability)
      end
    end

    test "admins and super admins have every admin capability" do
      for role <- [:admin, :super_admin], capability <- Policy.capabilities() do
        assert Policy.can?(scope_for(role), capability)
      end
    end

    test "a nil scope has no capabilities" do
      refute Policy.can?(nil, :manage_users)
    end
  end

  describe "can_manage_user?/2" do
    test "an admin can manage members and moderators" do
      scope = scope_for(:admin)

      assert Policy.can_manage_user?(scope, user_with_role(:member))
      assert Policy.can_manage_user?(scope, user_with_role(:moderator))
    end

    test "an admin cannot manage admins, super admins, or themselves" do
      admin = user_with_role(:admin)
      scope = Scope.for_user(admin)

      refute Policy.can_manage_user?(scope, admin)
      refute Policy.can_manage_user?(scope, user_with_role(:admin))
      refute Policy.can_manage_user?(scope, user_with_role(:super_admin))
    end

    test "a super admin can manage everyone except themselves" do
      super = user_with_role(:super_admin)
      scope = Scope.for_user(super)

      refute Policy.can_manage_user?(scope, super)
      assert Policy.can_manage_user?(scope, user_with_role(:member))
      assert Policy.can_manage_user?(scope, user_with_role(:moderator))
      assert Policy.can_manage_user?(scope, user_with_role(:admin))
      assert Policy.can_manage_user?(scope, user_with_role(:super_admin))
    end

    test "moderators and members cannot manage anyone" do
      for role <- [:member, :moderator] do
        scope = scope_for(role)

        refute Policy.can_manage_user?(scope, user_with_role(:member))
        refute Policy.can_manage_user?(scope, user_with_role(:moderator))
      end
    end
  end

  describe "can_view_user?/2" do
    test "an admin can view lower-ranked users and themselves" do
      admin = user_with_role(:admin)
      scope = Scope.for_user(admin)

      assert Policy.can_view_user?(scope, admin)
      assert Policy.can_view_user?(scope, user_with_role(:member))
      assert Policy.can_view_user?(scope, user_with_role(:moderator))
      refute Policy.can_view_user?(scope, user_with_role(:admin))
      refute Policy.can_view_user?(scope, user_with_role(:super_admin))
    end

    test "a super admin can view everyone" do
      super = user_with_role(:super_admin)
      scope = Scope.for_user(super)

      assert Policy.can_view_user?(scope, super)
      assert Policy.can_view_user?(scope, user_with_role(:member))
      assert Policy.can_view_user?(scope, user_with_role(:moderator))
      assert Policy.can_view_user?(scope, user_with_role(:admin))
      assert Policy.can_view_user?(scope, user_with_role(:super_admin))
    end
  end

  describe "can_assign_role?/2" do
    test "admins can assign member and moderator only" do
      scope = scope_for(:admin)

      assert Policy.can_assign_role?(scope, :member)
      assert Policy.can_assign_role?(scope, :moderator)
      refute Policy.can_assign_role?(scope, :admin)
      refute Policy.can_assign_role?(scope, :super_admin)
    end

    test "super admins can assign every role" do
      scope = scope_for(:super_admin)

      for role <- [:member, :moderator, :admin, :super_admin] do
        assert Policy.can_assign_role?(scope, role)
      end
    end
  end

  describe "visible_roles/1" do
    test "admins only see members and moderators" do
      assert Policy.visible_roles(scope_for(:admin)) == [:member, :moderator]
    end

    test "super admins see every role" do
      assert Policy.visible_roles(scope_for(:super_admin)) ==
               [:member, :moderator, :admin, :super_admin]
    end

    test "members and moderators see no users" do
      assert Policy.visible_roles(scope_for(:member)) == []
      assert Policy.visible_roles(scope_for(:moderator)) == []
    end
  end

  defp scope_for(role) do
    role
    |> user_with_role()
    |> Scope.for_user()
  end

  defp user_with_role(:member), do: user_fixture()

  defp user_with_role(role) do
    {:ok, user} = Accounts.update_user_role(user_fixture(), role)
    user
  end
end
