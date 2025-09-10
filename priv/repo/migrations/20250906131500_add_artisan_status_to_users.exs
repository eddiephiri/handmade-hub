defmodule HandmadeHub.Repo.Migrations.AddArtisanStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :artisan_status, :string, default: "pending", null: false
      add :suspended_at, :utc_datetime
    end

    create index(:users, [:role, :artisan_status])
  end
end
