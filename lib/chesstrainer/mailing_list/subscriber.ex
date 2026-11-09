defmodule Chesstrainer.MailingList.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  alias Chesstrainer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "mailing_list_subscribers" do
    field :email, :string
    field :source, Ecto.Enum, values: [:home, :registration], default: :home
    field :confirmed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime
    field :confirmation_sent_at, :utc_datetime
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for subscribing an email address.

  `:source` and `:user_id` are programmatic: the context sets them on the
  struct, never from user-supplied params.
  """
  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email])
    |> update_change(:email, &String.trim/1)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end
end
