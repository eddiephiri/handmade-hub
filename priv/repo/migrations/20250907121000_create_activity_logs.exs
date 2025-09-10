defmodule HandmadeHub.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :admin_id, references(:admins, on_delete: :nilify_all)
      add :target_user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:activity_logs, [:target_user_id])
    create index(:activity_logs, [:admin_id])
    create index(:activity_logs, [:action])
    create index(:activity_logs, [:inserted_at])
  end
end
