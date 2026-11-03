defmodule Chesstrainer.Repo.Migrations.AddRatingsToUsersAndEndgames do
  use Ecto.Migration

  def change do
    alter table(:endgames) do
      modify :rating, :float, default: 1500.0
      modify :rating_deviation, :float, default: 350.0
    end

    alter table(:users) do
      add :rating, :float, null: false, default: 1500.0
      add :rating_deviation, :float, null: false, default: 350.0
    end
  end
end
