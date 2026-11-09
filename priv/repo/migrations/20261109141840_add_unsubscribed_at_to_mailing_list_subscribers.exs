defmodule Chesstrainer.Repo.Migrations.AddUnsubscribedAtToMailingListSubscribers do
  use Ecto.Migration

  def change do
    alter table(:mailing_list_subscribers) do
      add :unsubscribed_at, :utc_datetime
    end
  end
end
