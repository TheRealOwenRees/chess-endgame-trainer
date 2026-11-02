defmodule Chesstrainer.Repo.Migrations.CreateEndgamesThemes do
  use Ecto.Migration

  def change do
    create table(:endgames_themes, primary_key: false) do
      add :endgame_id, references(:endgames, type: :binary_id, on_delete: :delete_all)
      add :theme_id, references(:themes, on_delete: :delete_all)
    end

    create unique_index(:endgames_themes, [:endgame_id, :theme_id])
  end
end
