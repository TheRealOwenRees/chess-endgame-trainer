defmodule Chesstrainer.Repo.Migrations.CreateThemeSuggestions do
  use Ecto.Migration

  def change do
    create table(:theme_suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :endgame_id, references(:endgames, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :theme_id, references(:themes, on_delete: :delete_all)
      add :proposed_name, :string
      add :status, :string, null: false, default: "pending"
      add :reviewer_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime
      add :note, :string

      timestamps(type: :utc_datetime)
    end

    create constraint(:theme_suggestions, :one_target,
             check: "num_nonnulls(theme_id, proposed_name) = 1"
           )

    create constraint(:theme_suggestions, :status_in_allowed,
             check: "status in ('pending', 'accepted', 'rejected', 'merged')"
           )

    create unique_index(:theme_suggestions, [:endgame_id, :theme_id, :user_id],
             where: "theme_id IS NOT NULL",
             name: :theme_suggestions_existing_unique
           )

    create unique_index(:theme_suggestions, [:endgame_id, :user_id, "lower(proposed_name)"],
             where: "proposed_name IS NOT NULL",
             name: :theme_suggestions_proposed_unique
           )

    create index(:theme_suggestions, [:endgame_id, :status])
    create index(:theme_suggestions, [:status, :inserted_at])
    create index(:theme_suggestions, [:user_id, :inserted_at])
  end
end
