defmodule HandmadeHub.Repo.Migrations.AddUserRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "buyer"
    end
  end
end
