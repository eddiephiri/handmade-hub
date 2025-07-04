defmodule HandmadeHub.Repo.Migrations.AddCategoryToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :category, :string
    end
  end
end
