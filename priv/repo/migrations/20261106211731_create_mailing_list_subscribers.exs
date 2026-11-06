defmodule Chesstrainer.Repo.Migrations.CreateMailingListSubscribers do
  use Ecto.Migration

  def change do
    create table(:mailing_list_subscribers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :source, :string, null: false, default: "home"
      add :confirmed_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mailing_list_subscribers, [:email])
    create index(:mailing_list_subscribers, [:user_id])
  end
end
