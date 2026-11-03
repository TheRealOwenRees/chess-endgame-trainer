defmodule Chesstrainer.Accounts.RoleTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Accounts.Role

  test "values/0 returns roles from least to most authority" do
    assert Role.values() == [:member, :moderator, :admin, :super_admin]
  end

  test "rank/1 orders roles" do
    assert Role.rank(:member) < Role.rank(:moderator)
    assert Role.rank(:moderator) < Role.rank(:admin)
    assert Role.rank(:admin) < Role.rank(:super_admin)
  end

  test "at_least?/2 compares ranks" do
    assert Role.at_least?(:admin, :admin)
    assert Role.at_least?(:super_admin, :admin)
    assert Role.at_least?(:moderator, :member)
    refute Role.at_least?(:moderator, :admin)
    refute Role.at_least?(:member, :moderator)
  end

  test "at_least?/2 is false when there is no valid role" do
    refute Role.at_least?(nil, :member)
    refute Role.at_least?(:unknown, :member)
  end

  test "admin?/1 is true only for admin and above" do
    assert Role.admin?(:admin)
    assert Role.admin?(:super_admin)
    refute Role.admin?(:moderator)
    refute Role.admin?(:member)
    refute Role.admin?(nil)
  end
end
