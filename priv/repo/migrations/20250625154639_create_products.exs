defmodule HandmadeHub.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string
      add :description, :text
      add :price, :decimal
      add :quantity, :integer
      add :image, :string
      add :artisan_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:artisan_id])
  end
end
