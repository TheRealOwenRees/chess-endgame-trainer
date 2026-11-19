defmodule Chesstrainer.Themes.ThemeSuggestion do
  @moduledoc """
  A player's proposal to add a technique theme to an endgame.

  A suggestion targets either an existing theme (`theme_id`) or a new name
  (`proposed_name`), never both. It is stored independently of the endgame's
  theme links: only a moderator decision in the review queue turns a suggestion
  into a `community` link.

  `status` starts as `pending`; the remaining values are for the review queue.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses [pending: "pending", accepted: "accepted", rejected: "rejected", merged: "merged"]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "theme_suggestions" do
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :proposed_name, :string
    field :note, :string
    field :reviewed_at, :utc_datetime

    belongs_to :endgame, Chesstrainer.Endgames.Endgame, type: :binary_id
    belongs_to :user, Chesstrainer.Accounts.User, type: :binary_id
    belongs_to :theme, Chesstrainer.Themes.Theme

    belongs_to :reviewer, Chesstrainer.Accounts.User,
      foreign_key: :reviewer_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:theme_id, :proposed_name])
    |> update_change(:proposed_name, fn
      name when is_binary(name) -> String.trim(name)
      name -> name
    end)
    |> validate_one_target()
    |> validate_length(:proposed_name, min: 1, max: 60)
    |> unique_constraint([:endgame_id, :theme_id, :user_id],
      name: :theme_suggestions_existing_unique,
      message: "you already suggested this theme"
    )
    |> unique_constraint(:proposed_name,
      name: :theme_suggestions_proposed_unique,
      message: "you already suggested that name"
    )
    |> check_constraint(:status, name: :theme_suggestions_status_in_allowed)
  end

  defp validate_one_target(changeset) do
    theme_id = get_field(changeset, :theme_id)
    name = get_field(changeset, :proposed_name)

    case {is_nil(theme_id), is_binary(name) and String.trim(name) != ""} do
      {false, false} -> changeset
      {true, true} -> changeset
      _ -> add_error(changeset, :base, "choose an existing theme or propose a name, not both")
    end
  end
end
