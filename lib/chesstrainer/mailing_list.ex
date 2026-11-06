defmodule Chesstrainer.MailingList do
  @moduledoc """
  The marketing mailing list.

  Addresses arrive from the signup form on the landing page and from the
  opt-in checkbox on registration. A subscriber is only active once their
  address is confirmed: the landing-page form sends a confirmation email, while
  the registration checkbox relies on the account-confirmation email and is
  confirmed when the user's account is. A subscriber created from the landing
  page has no user; one created from registration is linked to the user so
  deleting the account also removes their address.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Accounts.User
  alias Chesstrainer.MailingList.Subscriber
  alias Chesstrainer.Repo

  @doc """
  Requests a subscription from the landing-page form.

  Returns `{:ok, :confirmation_required}` for a new or still-unconfirmed
  address, so the caller can send a confirmation email, and
  `{:ok, :already_subscribed}` for an address that has already confirmed.

      iex> subscribe("player@example.com")
      {:ok, :confirmation_required}

      iex> confirm("player@example.com")
      {:ok, %Subscriber{}}

      iex> subscribe("player@example.com")
      {:ok, :already_subscribed}
  """
  def subscribe(email, opts \\ []) when is_binary(email) do
    changeset =
      %Subscriber{source: Keyword.get(opts, :source, :home)}
      |> Subscriber.changeset(%{email: email})

    if changeset.valid? do
      email = Ecto.Changeset.get_field(changeset, :email)

      case Repo.get_by(Subscriber, email: email) do
        %Subscriber{confirmed_at: confirmed_at} when not is_nil(confirmed_at) ->
          {:ok, :already_subscribed}

        %Subscriber{} ->
          {:ok, :confirmation_required}

        nil ->
          insert_subscription(changeset, email)
      end
    else
      {:error, changeset}
    end
  end

  @doc """
  Records a newly registered user's mailing-list opt-in.

  The subscriber stays unconfirmed until the account itself is confirmed. If
  the address was already subscribed anonymously, the existing row is linked to
  the user and re-sourced so the account deletion cascade removes it.
  """
  def subscribe_user(%User{} = user) do
    %Subscriber{source: :registration, user_id: user.id}
    |> Subscriber.changeset(%{email: user.email})
    |> Repo.insert(
      on_conflict: {:replace, [:user_id, :source, :updated_at]},
      conflict_target: :email
    )
  end

  @doc """
  Confirms a subscription by email address.

  Returns `{:error, :not_found}` when the address is not on the list.
  """
  def confirm(email) when is_binary(email) do
    case Repo.get_by(Subscriber, email: String.trim(email)) do
      nil ->
        {:error, :not_found}

      %Subscriber{confirmed_at: nil} = subscriber ->
        subscriber
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
        |> Repo.update()

      %Subscriber{} = subscriber ->
        {:ok, subscriber}
    end
  end

  @doc """
  Confirms the subscription linked to a user whose account was just confirmed.

  Registration opt-ins use the account-confirmation email as their proof of
  address ownership, so this is called from the account confirmation flow.
  """
  def confirm_user_subscription(%User{} = user) do
    now = DateTime.utc_now(:second)

    Subscriber
    |> where([s], s.user_id == ^user.id and is_nil(s.confirmed_at))
    |> Repo.update_all(set: [confirmed_at: now, updated_at: now])
  end

  @doc "Returns the number of confirmed addresses on the mailing list."
  def count_confirmed_subscribers do
    Subscriber
    |> where([s], not is_nil(s.confirmed_at))
    |> Repo.aggregate(:count)
  end

  defp insert_subscription(changeset, email) do
    case Repo.insert(changeset) do
      {:ok, _subscriber} ->
        {:ok, :confirmation_required}

      {:error, changeset} ->
        # A concurrent request may have inserted the address between the read
        # above and this insert; the unique constraint decides, so re-read it.
        if email_taken?(changeset) do
          case Repo.get_by(Subscriber, email: email) do
            %Subscriber{confirmed_at: nil} -> {:ok, :confirmation_required}
            %Subscriber{} -> {:ok, :already_subscribed}
            nil -> {:error, changeset}
          end
        else
          {:error, changeset}
        end
    end
  end

  defp email_taken?(changeset) do
    Enum.any?(changeset.errors, fn
      {:email, {_message, opts}} -> opts[:constraint] == :unique
      _other -> false
    end)
  end
end
