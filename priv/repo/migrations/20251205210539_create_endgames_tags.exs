defmodule Chesstrainer.Repo.Migrations.CreateEndgamesTags do
  use Ecto.Migration

  def change do
    create table(:endgames_tags, primary_key: false) do
      add :endgame_id, references(:endgames, type: :binary_id, on_delete: :delete_all)
      add :tag_id, references(:tags, on_delete: :delete_all)
    end

    create unique_index(:endgames_tags, [:endgame_id, :tag_id])
  end
end
