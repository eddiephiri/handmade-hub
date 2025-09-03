defmodule HandmadeHub.Repo.Migrations.CreateEmailQueue do
  use Ecto.Migration

  def change do
    create table(:email_queue) do
      add :to, :string, null: false
      add :subject, :string, null: false
      add :text_body, :text, null: false
      add :type, :string, null: false, default: "generic"
      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false, default: 5
      add :last_error, :text
      add :scheduled_at, :utc_datetime, null: false
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:email_queue, [:status, :scheduled_at])
  end
end
