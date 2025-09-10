defmodule HandmadeHub.Repo.Migrations.AddReplyToToEmailQueue do
  use Ecto.Migration

  def change do
    alter table(:email_queue) do
      add :reply_to, :string
    end
  end
end
