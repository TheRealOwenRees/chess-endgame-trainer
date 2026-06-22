defmodule Chesstrainer.Repo.Migrations.CreateEndgames do
  use Ecto.Migration

  def change do
    create table(:endgames, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :fen, :string
      add :color, :string
      add :key, :string
      add :message, :text
      add :notes, :text
      add :result, :string
      add :rating, :integer, default: 1500
      add :rating_deviation, :integer, default: 350
      add :times_attempted, :integer, default: 0
      add :times_solved, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:endgames, [:fen])
  end
end
