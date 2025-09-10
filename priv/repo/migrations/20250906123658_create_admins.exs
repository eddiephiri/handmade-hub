defmodule HandmadeHub.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    create table(:admins) do
      add :email, :citext, null: false
      add :username, :string
      add :hashed_password, :string
      add :role, :string, null: false, default: "support"
      add :permissions, :map
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admins, [:email])
    create unique_index(:admins, [:username])
  end
end
