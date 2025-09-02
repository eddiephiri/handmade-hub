defmodule HandmadeHub.Repo.Migrations.CreateCartsAndCartItems do
  use Ecto.Migration

  def change do
    # Create carts table
    create table(:carts) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :session_id, :string
      add :status, :string, default: "active" # active, abandoned, converted
      
      timestamps(type: :utc_datetime)
    end

    create index(:carts, [:user_id])
    create index(:carts, [:session_id])
    create index(:carts, [:status])

    # Create cart_items table
    create table(:cart_items) do
      add :cart_id, references(:carts, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :quantity, :integer, null: false, default: 1
      add :price, :decimal, null: false # Store price at time of adding to cart
      
      timestamps(type: :utc_datetime)
    end

    create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])
    create unique_index(:cart_items, [:cart_id, :product_id])
  end
end
