defmodule Chesstrainer.Attempts.Attempt do
  @moduledoc """
  A per-user playthrough of an endgame, ending solved or failed.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "attempts" do
    field :outcome, Ecto.Enum, values: [:solved, :failed]
    field :rated_at, :utc_datetime

    belongs_to :user, Chesstrainer.Accounts.User
    belongs_to :endgame, Chesstrainer.Endgames.Endgame

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [:outcome, :rated_at])
    |> validate_required([:outcome])
  end
end
