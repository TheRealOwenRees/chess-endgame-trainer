defmodule Chesstrainer.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string
      add :category, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name, :category])
  end
end
