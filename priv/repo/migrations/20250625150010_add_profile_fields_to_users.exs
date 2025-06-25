defmodule HandmadeHub.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :bio, :text
      add :profile_image, :string
    end
  end
end
