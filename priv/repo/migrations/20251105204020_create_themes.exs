defmodule Chesstrainer.Repo.Migrations.CreateThemes do
  use Ecto.Migration

  def change do
    create table(:themes) do
      add :name, :string
      add :category, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:themes, [:name, :category])
  end
end
