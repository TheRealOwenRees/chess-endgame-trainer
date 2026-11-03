defmodule Mix.Tasks.Accounts.PromoteTest do
  use Chesstrainer.DataCase

  import Chesstrainer.AccountsFixtures
  import ExUnit.CaptureIO

  alias Chesstrainer.Accounts

  test "promotes a user by username" do
    user = user_fixture()

    output =
      capture_io(fn -> Mix.Tasks.Accounts.Promote.run([user.username, "admin"]) end)

    assert output =~ "role to admin"
    assert Accounts.get_user!(user.id).role == :admin
  end

  test "promotes a user by email" do
    user = user_fixture()

    capture_io(fn -> Mix.Tasks.Accounts.Promote.run([user.email, "super_admin"]) end)

    assert Accounts.get_user!(user.id).role == :super_admin
  end

  test "raises for an unknown role" do
    user = user_fixture()

    assert_raise Mix.Error, ~r/Unknown role/, fn ->
      Mix.Tasks.Accounts.Promote.run([user.username, "wizard"])
    end
  end

  test "raises when the user does not exist" do
    assert_raise Mix.Error, ~r/No user found/, fn ->
      Mix.Tasks.Accounts.Promote.run(["nobody@example.com", "admin"])
    end
  end

  test "raises without the expected arguments" do
    assert_raise Mix.Error, ~r/Usage/, fn ->
      Mix.Tasks.Accounts.Promote.run([])
    end
  end
end
