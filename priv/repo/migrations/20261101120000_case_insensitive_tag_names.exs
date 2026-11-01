defmodule Chesstrainer.Repo.Migrations.CaseInsensitiveTagNames do
  use Ecto.Migration

  def up do
    drop index(:tags, [:name, :category])

    create unique_index(:tags, ["lower(name)", :category], name: :tags_name_category_lower_index)
  end

  def down do
    drop index(:tags, ["lower(name)", :category], name: :tags_name_category_lower_index)

    create unique_index(:tags, [:name, :category])
  end
end
