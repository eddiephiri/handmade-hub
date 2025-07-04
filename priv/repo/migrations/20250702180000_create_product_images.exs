defmodule HandmadeHub.Repo.Migrations.CreateProductImages do
  use Ecto.Migration

  def change do
    create table(:product_images) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :image_url, :string, null: false
      add :is_primary, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:product_images, [:product_id])
    create unique_index(:product_images, [:product_id, :is_primary], where: "is_primary")
  end
end
