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

  describe "unsubscribe/1" do
    test "marks a confirmed address as unsubscribed" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      {:ok, _subscriber} = MailingList.confirm("player@example.com")

      assert {:ok, %Subscriber{unsubscribed_at: unsubscribed_at}} =
               MailingList.unsubscribe("player@example.com")

      assert unsubscribed_at
      assert MailingList.count_confirmed_subscribers() == 0
    end

    test "is idempotent" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      {:ok, _subscriber} = MailingList.confirm("player@example.com")

      {:ok, first} = MailingList.unsubscribe("player@example.com")
      {:ok, second} = MailingList.unsubscribe("player@example.com")

      assert first.unsubscribed_at == second.unsubscribed_at
    end

    test "returns not found for an unknown address" do
      assert {:error, :not_found} = MailingList.unsubscribe("nobody@example.com")
    end
  end

  describe "unsubscribe_user/1" do
    test "unsubscribes the address linked to the user" do
      user = user_fixture()
      {:ok, _subscriber} = MailingList.subscribe_user(user)
      MailingList.confirm_user_subscription(user)

      assert {:ok, %Subscriber{unsubscribed_at: unsubscribed_at}} =
               MailingList.unsubscribe_user(user)

      assert unsubscribed_at
      refute MailingList.user_subscribed?(user)
    end

    test "returns not found when the user is not on the list" do
      assert {:error, :not_found} = MailingList.unsubscribe_user(user_fixture())
    end
  end

  describe "user_subscribed?/1" do
    test "is true only for a confirmed, active subscription" do
      user = user_fixture()
      {:ok, _subscriber} = MailingList.subscribe_user(user)

      refute MailingList.user_subscribed?(user)

      MailingList.confirm_user_subscription(user)
      assert MailingList.user_subscribed?(user)

      {:ok, _subscriber} = MailingList.unsubscribe_user(user)
      refute MailingList.user_subscribed?(user)
    end
  end

  describe "re-subscribing after unsubscribe" do
    test "requires a fresh confirmation and clears the unsubscribe" do
      {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")
      {:ok, _subscriber} = MailingList.confirm("player@example.com")
      {:ok, _subscriber} = MailingList.unsubscribe("player@example.com")

      assert {:ok, :confirmation_required} = MailingList.subscribe("player@example.com")

      assert {:ok, %Subscriber{confirmed_at: confirmed_at, unsubscribed_at: nil}} =
               MailingList.confirm("player@example.com")

      assert confirmed_at
      assert MailingList.count_confirmed_subscribers() == 1
    end
  end

  describe "update_subscriber_email/2" do
    test "moves the linked subscription to the new address" do
      user = user_fixture()
      {:ok, _subscriber} = MailingList.subscribe_user(user)
      MailingList.confirm_user_subscription(user)

      new_email = unique_user_email()

      assert {:ok, %Subscriber{email: ^new_email}} =
               MailingList.update_subscriber_email(user, new_email)

      assert Repo.get_by(Subscriber, user_id: user.id).email == new_email
    end

    test "removes an anonymous row that already holds the new address" do
      user = user_fixture()
      {:ok, _subscriber} = MailingList.subscribe_user(user)
      new_email = unique_user_email()
      {:ok, :confirmation_required} = MailingList.subscribe(new_email)

      assert {:ok, _subscriber} = MailingList.update_subscriber_email(user, new_email)

      assert Repo.aggregate(Subscriber, :count) == 1
      assert %Subscriber{user_id: user_id} = Repo.get_by(Subscriber, email: new_email)
      assert user_id == user.id
    end

    test "keeps an unsubscribe from an anonymous row at the new address" do
      user = user_fixture()
      {:ok, _subscriber} = MailingList.subscribe_user(user)
      MailingList.confirm_user_subscription(user)
      new_email = unique_user_email()
      {:ok, :confirmation_required} = MailingList.subscribe(new_email)
      {:ok, _subscriber} = MailingList.confirm(new_email)
      {:ok, _subscriber} = MailingList.unsubscribe(new_email)

      assert {:ok, %Subscriber{unsubscribed_at: unsubscribed_at}} =
               MailingList.update_subscriber_email(user, new_email)

      assert unsubscribed_at
      refute MailingList.user_subscribed?(user)
    end

    test "does nothing when the user is not on the list" do
      user = user_fixture()

      assert {:ok, :no_subscription} =
               MailingList.update_subscriber_email(user, unique_user_email())
    end
  end
end
