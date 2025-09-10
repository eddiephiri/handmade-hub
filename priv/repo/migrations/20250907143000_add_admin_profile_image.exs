defmodule HandmadeHub.Repo.Migrations.AddAdminProfileImage do
  use Ecto.Migration

  def change do
    alter table(:admins) do
      add :profile_image, :string
    end
  end
end
