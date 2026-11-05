defmodule Chesstrainer.DailyPuzzles.DailyPuzzle do
  @moduledoc """
  A persisted endgame assignment for one UTC day.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Chesstrainer.Endgames.Endgame

  @foreign_key_type :binary_id

  schema "daily_puzzles" do
    field :date, :date

    belongs_to :endgame, Endgame

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(daily_puzzle, attrs) do
    daily_puzzle
    |> cast(attrs, [:date, :endgame_id])
    |> validate_required([:date, :endgame_id])
    |> unique_constraint(:date)
    |> foreign_key_constraint(:endgame_id)
  end
end
