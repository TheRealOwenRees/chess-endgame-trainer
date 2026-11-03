defmodule Chesstrainer.Repo.Migrations.CreateAttempts do
  use Ecto.Migration

  def change do
    create table(:attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :endgame_id, references(:endgames, type: :binary_id, on_delete: :delete_all),
        null: false

      add :outcome, :string, null: false
      add :rated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Independent foreign-key indexes so cascade deletes stay cheap.
    create index(:attempts, [:user_id])
    create index(:attempts, [:endgame_id])

    # Rating-window lookup: the latest rated attempt for a user/endgame pair.
    create index(:attempts, [:user_id, :endgame_id, :rated_at], where: "rated_at IS NOT NULL")
  end
end
