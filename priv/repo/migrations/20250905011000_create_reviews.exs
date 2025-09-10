defmodule HandmadeHub.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all)
      add :artisan_id, references(:users, on_delete: :delete_all)
      add :rating, :integer, null: false
      add :comment, :text

      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:product_id])
    create index(:reviews, [:artisan_id])
    create index(:reviews, [:user_id])

    # Ensure a user can only review a product once
    create unique_index(:reviews, [:user_id, :product_id], where: "product_id IS NOT NULL", name: :reviews_user_product_unique)
    # Ensure a user can only review an artisan once
    create unique_index(:reviews, [:user_id, :artisan_id], where: "artisan_id IS NOT NULL", name: :reviews_user_artisan_unique)
  end
end
