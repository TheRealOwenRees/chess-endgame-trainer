defmodule Chesstrainer.AccountsAdminTest do
  use Chesstrainer.DataCase, async: false

  require Logger

  import Chesstrainer.AccountsFixtures
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope

  describe "list_users_for_admin/2" do
    test "an admin only sees members and moderators" do
      admin = user_with_role(:admin)
      member = user_fixture()
      moderator = user_with_role(:moderator)
      other_admin = user_with_role(:admin)
      super_admin = user_with_role(:super_admin)

      assert {:ok, users} = Accounts.list_users_for_admin(Scope.for_user(admin))
      ids = users |> Enum.map(& &1.id) |> MapSet.new()

      assert ids == MapSet.new([member.id, moderator.id])
      refute MapSet.member?(ids, other_admin.id)
      refute MapSet.member?(ids, super_admin.id)

      assert {:ok, 2} = Accounts.count_users_for_admin(Scope.for_user(admin))
    end

    test "a super admin sees every role, including themselves" do
      super_admin = user_with_role(:super_admin)
      member = user_fixture()
      moderator = user_with_role(:moderator)
      admin = user_with_role(:admin)

      assert {:ok, users} = Accounts.list_users_for_admin(Scope.for_user(super_admin))
      ids = users |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.new([super_admin.id, member.id, moderator.id, admin.id]) == ids
    end

    test "search matches email and username case-insensitively" do
      admin = user_with_role(:admin)
      target = user_fixture(%{email: "FindMe@Example.com", username: "searchable_name"})
      user_fixture()

      assert {:ok, [found]} =
               Accounts.list_users_for_admin(Scope.for_user(admin), search: "findme")

      assert found.id == target.id

      assert {:ok, [found]} =
               Accounts.list_users_for_admin(Scope.for_user(admin), search: "SEARCHABLE")

      assert found.id == target.id

      assert {:ok, []} = Accounts.list_users_for_admin(Scope.for_user(admin), search: "no-match")
    end

    test "paginates 25 users per page" do
      admin = user_with_role(:admin)

      for _ <- 1..26 do
        user_fixture()
      end

      assert {:ok, 26} = Accounts.count_users_for_admin(Scope.for_user(admin))
      assert {:ok, page_one} = Accounts.list_users_for_admin(Scope.for_user(admin), page: 1)
      assert length(page_one) == 25
      assert {:ok, page_two} = Accounts.list_users_for_admin(Scope.for_user(admin), page: 2)
      assert length(page_two) == 1
    end

    test "members and moderators are rejected" do
      for role <- [:member, :moderator] do
        scope = scope_for(role)

        assert {:error, :unauthorized} = Accounts.list_users_for_admin(scope)
        assert {:error, :unauthorized} = Accounts.count_users_for_admin(scope)
        assert {:error, :unauthorized} = Accounts.get_user_for_admin(scope, user_fixture().id)
      end
    end
  end

  describe "update_user_as_admin/3" do
    test "an admin can change a member's role and plan" do
      admin = user_with_role(:admin)
      member = user_fixture()

      previous_level = Logger.level()
      Logger.configure(level: :info)

      log =
        try do
          capture_log(
            [format: "$message $metadata\n", metadata: [:actor_id, :target_id, :fields]],
            fn ->
              assert {:ok, updated} =
                       Accounts.update_user_as_admin(Scope.for_user(admin), member, %{
                         "role" => "moderator",
                         "plan" => "premium"
                       })

              assert updated.role == :moderator
              assert updated.plan == :premium
            end
          )
        after
          Logger.configure(level: previous_level)
        end

      assert log =~ "admin.user.updated"
      assert log =~ admin.id
      assert log =~ member.id
      refute log =~ member.email
    end

    test "an admin can change a moderator" do
      admin = user_with_role(:admin)
      moderator = user_with_role(:moderator)

      assert {:ok, updated} =
               Accounts.update_user_as_admin(Scope.for_user(admin), moderator, %{
                 "role" => "member"
               })

      assert updated.role == :member
    end

    test "an admin cannot change another admin or a super admin" do
      admin = user_with_role(:admin)

      for target <- [user_with_role(:admin), user_with_role(:super_admin)] do
        assert {:error, :unauthorized} =
                 Accounts.update_user_as_admin(Scope.for_user(admin), target, %{
                   "plan" => "premium"
                 })

        assert Accounts.get_user!(target.id).plan == :free
      end
    end

    test "an admin cannot promote a member above their own rank" do
      admin = user_with_role(:admin)
      member = user_fixture()

      assert {:error, :unauthorized} =
               Accounts.update_user_as_admin(Scope.for_user(admin), member, %{"role" => "admin"})

      assert Accounts.get_user!(member.id).role == :member
    end

    test "a super admin can change an admin's role and plan" do
      super_admin = user_with_role(:super_admin)
      admin = user_with_role(:admin)

      assert {:ok, updated} =
               Accounts.update_user_as_admin(Scope.for_user(super_admin), admin, %{
                 "role" => "moderator",
                 "plan" => "premium"
               })

      assert updated.role == :moderator
      assert updated.plan == :premium
    end

    test "a super admin can change another super admin's plan" do
      super_admin = user_with_role(:super_admin)
      other_super_admin = user_with_role(:super_admin)

      assert {:ok, updated} =
               Accounts.update_user_as_admin(
                 Scope.for_user(super_admin),
                 other_super_admin,
                 %{"plan" => "premium"}
               )

      assert updated.plan == :premium
    end

    test "a super admin cannot change their own role" do
      super_admin = user_with_role(:super_admin)

      assert {:error, :own_role} =
               Accounts.update_user_as_admin(
                 Scope.for_user(super_admin),
                 super_admin,
                 %{"role" => "admin"}
               )

      assert Accounts.get_user!(super_admin.id).role == :super_admin
    end

    test "the last super admin cannot be demoted" do
      # The actor has the super-admin capability but is not persisted, leaving
      # exactly one super admin in the database.
      actor = %{user_fixture() | role: :super_admin}
      target = user_with_role(:super_admin)

      assert {:error, :last_super_admin} =
               Accounts.update_user_as_admin(Scope.for_user(actor), target, %{
                 "role" => "admin"
               })

      assert Accounts.get_user!(target.id).role == :super_admin
    end

    test "members and moderators are rejected" do
      for role <- [:member, :moderator] do
        target = user_fixture()

        assert {:error, :unauthorized} =
                 Accounts.update_user_as_admin(scope_for(role), target, %{"plan" => "premium"})
      end
    end
  end

  describe "invite_user_as_admin/3" do
    test "an admin can invite a member and an email is sent" do
      admin = user_with_role(:admin)
      attrs = invite_attrs()

      assert {:ok, invited} =
               Accounts.invite_user_as_admin(Scope.for_user(admin), attrs, &password_reset_url/1)

      assert invited.email == attrs["email"]
      assert invited.username == attrs["username"]
      assert invited.role == :member
      assert invited.plan == :free
      assert invited.confirmed_at

      assert_email_sent(
        to: invited.email,
        subject: "You're invited to Inner Square Chess"
      )
    end

    test "a super admin can invite an admin" do
      super_admin = user_with_role(:super_admin)

      assert {:ok, invited} =
               Accounts.invite_user_as_admin(
                 Scope.for_user(super_admin),
                 Map.put(invite_attrs(), "role", "admin"),
                 &password_reset_url/1
               )

      assert invited.role == :admin
    end

    test "an admin cannot invite an admin or super admin" do
      admin = user_with_role(:admin)

      for role <- ["admin", "super_admin"] do
        attrs = Map.put(invite_attrs(), "role", role)

        assert {:error, :unauthorized} =
                 Accounts.invite_user_as_admin(
                   Scope.for_user(admin),
                   attrs,
                   &password_reset_url/1
                 )

        refute Accounts.get_user_by_email(attrs["email"])
      end
    end

    test "duplicate emails return the changeset error" do
      admin = user_with_role(:admin)
      existing = user_fixture()

      attrs = Map.put(invite_attrs(), "email", existing.email)

      assert {:error, changeset} =
               Accounts.invite_user_as_admin(
                 Scope.for_user(admin),
                 attrs,
                 &password_reset_url/1
               )

      assert changeset.errors[:email]
    end

    test "moderators and members are rejected" do
      for role <- [:member, :moderator] do
        assert {:error, :unauthorized} =
                 Accounts.invite_user_as_admin(
                   scope_for(role),
                   invite_attrs(),
                   &password_reset_url/1
                 )
      end
    end
  end

  describe "admin-initiated account emails" do
    test "an admin can send a password reset to a member" do
      admin = user_with_role(:admin)
      member = user_fixture()

      assert {:ok, _email} =
               Accounts.send_user_reset_password_instructions_as_admin(
                 Scope.for_user(admin),
                 member,
                 &password_reset_url/1
               )

      assert_email_sent(to: member.email, subject: "Reset password instructions")
    end

    test "an admin cannot send a password reset to another admin" do
      admin = user_with_role(:admin)
      other_admin = user_with_role(:admin)

      assert {:error, :unauthorized} =
               Accounts.send_user_reset_password_instructions_as_admin(
                 Scope.for_user(admin),
                 other_admin,
                 &password_reset_url/1
               )

      refute_email_sent()
    end

    test "a super admin can send a password reset to an admin" do
      super_admin = user_with_role(:super_admin)
      admin = user_with_role(:admin)

      assert {:ok, _email} =
               Accounts.send_user_reset_password_instructions_as_admin(
                 Scope.for_user(super_admin),
                 admin,
                 &password_reset_url/1
               )

      assert_email_sent(to: admin.email, subject: "Reset password instructions")
    end

    test "an admin can resend confirmation to an unconfirmed member" do
      admin = user_with_role(:admin)
      member = unconfirmed_user_fixture()

      assert {:ok, _email} =
               Accounts.resend_user_confirmation_instructions_as_admin(
                 Scope.for_user(admin),
                 member,
                 &confirmation_url/1
               )

      assert_email_sent(to: member.email, subject: "Confirmation instructions")
    end

    test "resending confirmation to a confirmed user reports the error" do
      admin = user_with_role(:admin)
      member = user_fixture()

      assert {:error, :already_confirmed} =
               Accounts.resend_user_confirmation_instructions_as_admin(
                 Scope.for_user(admin),
                 member,
                 &confirmation_url/1
               )
    end
  end

  defp password_reset_url(token), do: "http://localhost/users/reset-password/#{token}"
  defp confirmation_url(token), do: "http://localhost/users/confirm/#{token}"

  defp invite_attrs do
    %{
      "email" => unique_user_email(),
      "username" => unique_username(),
      "role" => "member",
      "plan" => "free"
    }
  end

  defp scope_for(role), do: role |> user_with_role() |> Scope.for_user()

  defp user_with_role(:member), do: user_fixture()

  defp user_with_role(role) do
    {:ok, user} = Accounts.update_user_role(user_fixture(), role)
    user
  end
end
