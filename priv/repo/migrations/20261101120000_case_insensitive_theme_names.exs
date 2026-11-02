defmodule Chesstrainer.Repo.Migrations.CaseInsensitiveThemeNames do
  use Ecto.Migration

  def up do
    drop index(:themes, [:name, :category])

    create unique_index(:themes, ["lower(name)", :category],
             name: :themes_name_category_lower_index
           )
  end

  def down do
    drop index(:themes, ["lower(name)", :category], name: :themes_name_category_lower_index)

    create unique_index(:themes, [:name, :category])
  end
end
