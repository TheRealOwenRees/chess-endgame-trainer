defmodule Chesstrainer.Endgames.Endgame do
  @moduledoc """
  A singular endgame entry
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "endgames" do
    field :fen, :string
    field :color, Ecto.Enum, values: [:white, :black]
    field :key, :string
    field :message, :string
    field :notes, :string
    field :result, Ecto.Enum, values: [:win, :loss, :draw]
    field :rating, :integer
    field :rating_deviation, :integer
    field :times_attempted, :integer
    field :times_solved, :integer

    many_to_many :tags, Chesstrainer.Tags.Tag,
      join_through: "endgames_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(endgame, attrs) do
    endgame
    |> cast(attrs, [:fen, :key, :message, :notes, :result, :rating, :color])
    |> validate_required([:fen, :color], message: "Invalid FEN")
    |> validate_required([:key, :result, :rating])
    |> validate_format(:key, ~r/^(?=.{5,10}$)KQ*R*[NB]*P*\sv\sKQ*R*[NB]*P*$/,
      message: "Key must follow pattern KQ.. v KQR.., max pieces 7"
    )
    |> unique_constraint(:fen, message: "FEN already exists")
  end
end
