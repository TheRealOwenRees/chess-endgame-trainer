defmodule Chesstrainer.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :name, :string
    field :category, Ecto.Enum, values: [endgame: "endgame", opening: "opening", tactic: "tactic"]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :category])
    |> validate_required([:name, :category])
    |> unique_constraint(:name)
  end
end
