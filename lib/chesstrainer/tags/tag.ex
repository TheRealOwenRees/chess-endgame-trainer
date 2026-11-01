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
    |> update_change(:name, fn
      name when is_binary(name) -> String.trim(name)
      name -> name
    end)
    |> validate_required([:name, :category])
    |> validate_length(:name, min: 1, max: 60)
    |> unique_constraint(:name, name: :tags_name_category_lower_index, message: "already exists")
  end
end
