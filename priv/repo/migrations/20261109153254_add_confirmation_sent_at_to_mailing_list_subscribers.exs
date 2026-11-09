defmodule Chesstrainer.Repo.Migrations.AddConfirmationSentAtToMailingListSubscribers do
  use Ecto.Migration

  def change do
    alter table(:mailing_list_subscribers) do
      add :confirmation_sent_at, :utc_datetime
    end
  end
end
