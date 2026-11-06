defmodule Chesstrainer.MailingListTest do
  use Chesstrainer.DataCase, async: true

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.MailingList
  alias Chesstrainer.MailingList.Subscriber

  describe "subscribe/2" do
    test "requests confirmation for a new address from the landing page" do
      assert {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")

      subscriber = Repo.get_by(Subscriber, email: "player@example.com")
      assert subscriber.source == :home
      assert subscriber.user_id == nil
      assert subscriber.confirmed_at == nil
      assert MailingList.count_confirmed_subscribers() == 0
    end

    test "trims surrounding whitespace" do
      assert {:ok, :confirmation_required} = MailingList.subscribe("  player@example.com  ")

      assert %Subscriber{email: "player@example.com"} =
               Repo.get_by(Subscriber, email: "player@example.com")
    end

    test "asks again instead of duplicating an unconfirmed address" do
      assert {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      assert {:ok, :confirmation_required} = MailingList.subscribe("Player@Example.com")
      assert Repo.aggregate(Subscriber, :count) == 1
    end

    test "reports an address that is already confirmed" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      {:ok, _subscriber} = MailingList.confirm("player@example.com")

      assert {:ok, :already_subscribed} = MailingList.subscribe("Player@Example.com")
      assert MailingList.count_confirmed_subscribers() == 1
    end

    test "rejects an invalid address" do
      assert {:error, changeset} = MailingList.subscribe("not an email")
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
      assert Repo.aggregate(Subscriber, :count) == 0
    end
  end

  describe "confirm/1" do
    test "confirms a pending subscription" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")

      assert {:ok, %Subscriber{} = subscriber} = MailingList.confirm("player@example.com")
      assert subscriber.confirmed_at
      assert MailingList.count_confirmed_subscribers() == 1
    end

    test "is idempotent" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      {:ok, confirmed} = MailingList.confirm("player@example.com")

      assert {:ok, %Subscriber{confirmed_at: confirmed_at}} =
               MailingList.confirm("player@example.com")

      assert confirmed_at == confirmed.confirmed_at
    end

    test "returns not found for an unknown address" do
      assert {:error, :not_found} = MailingList.confirm("nobody@example.com")
    end
  end

  describe "subscribe_user/1" do
    test "links an unconfirmed subscription to the user" do
      user = user_fixture()

      assert {:ok, %Subscriber{} = subscriber} = MailingList.subscribe_user(user)

      assert subscriber.email == user.email
      assert subscriber.source == :registration
      assert subscriber.user_id == user.id
      assert subscriber.confirmed_at == nil
    end

    test "upgrades an anonymous subscription with the same address" do
      user = user_fixture()
      {:ok, :confirmation_required} = MailingList.subscribe(user.email)

      assert {:ok, %Subscriber{}} = MailingList.subscribe_user(user)

      assert Repo.aggregate(Subscriber, :count) == 1

      subscriber = Repo.get_by(Subscriber, email: user.email)
      assert subscriber.user_id == user.id
      assert subscriber.source == :registration
    end

    test "deleting the user removes their linked subscription" do
      user = user_fixture()
      {:ok, _} = MailingList.subscribe_user(user)

      assert {:ok, _} = Accounts.delete_user(user)
      assert Repo.aggregate(Subscriber, :count) == 0
    end
  end

  describe "confirm_user_subscription/1" do
    test "confirms the subscription linked to the user" do
      user = user_fixture()
      {:ok, _} = MailingList.subscribe_user(user)

      MailingList.confirm_user_subscription(user)

      assert %Subscriber{confirmed_at: confirmed_at} =
               Repo.get_by(Subscriber, user_id: user.id)

      assert confirmed_at
    end

    test "leaves anonymous subscriptions alone" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      user = user_fixture()

      MailingList.confirm_user_subscription(user)

      assert %Subscriber{confirmed_at: nil} =
               Repo.get_by(Subscriber, email: "player@example.com")
    end
  end
end
