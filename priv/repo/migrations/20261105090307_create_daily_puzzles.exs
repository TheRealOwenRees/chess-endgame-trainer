defmodule Chesstrainer.Repo.Migrations.CreateDailyPuzzles do
  use Ecto.Migration

  def change do
    create table(:daily_puzzles) do
      add :date, :date, null: false

      add :endgame_id, references(:endgames, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_puzzles, [:date])
    create index(:daily_puzzles, [:endgame_id])
  end
end
