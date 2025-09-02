defmodule HandmadeHub.Repo.Migrations.CreateOrdersAndRelatedTables do
  use Ecto.Migration

  def change do
    # Create orders table
    create table(:orders) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :order_number, :string, null: false
      add :status, :string, default: "pending" # pending, processing, shipped, delivered, cancelled
      add :payment_status, :string, default: "pending" # pending, paid, failed, refunded
      add :payment_method, :string # mobile_money, card, cash_on_delivery
      add :subtotal, :decimal, null: false
      add :shipping_fee, :decimal, default: 0
      add :total, :decimal, null: false
      add :notes, :text
      
      # Customer info (for guest checkout)
      add :customer_email, :string
      add :customer_phone, :string
      add :customer_name, :string
      
      # Payment details
      add :payment_reference, :string # Transaction ID from payment provider
      add :mobile_money_provider, :string # mtn, airtel, zamtel
      add :mobile_money_number, :string
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:orders, [:order_number])
    create index(:orders, [:user_id])
    create index(:orders, [:status])
    create index(:orders, [:payment_status])
    create index(:orders, [:customer_email])

    # Create order_items table
    create table(:order_items) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :nilify_all)
      add :product_name, :string, null: false # Store product name at time of order
      add :product_price, :decimal, null: false # Store price at time of order
      add :quantity, :integer, null: false
      add :subtotal, :decimal, null: false
      
      timestamps(type: :utc_datetime)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])

    # Create shipping_addresses table
    create table(:shipping_addresses) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :recipient_name, :string, null: false
      add :phone_number, :string, null: false
      add :address_line_1, :string, null: false
      add :address_line_2, :string
      add :city, :string, null: false
      add :province, :string
      add :postal_code, :string
      add :country, :string, default: "Zambia"
      add :delivery_instructions, :text
      
      timestamps(type: :utc_datetime)
    end

    create index(:shipping_addresses, [:order_id])
  end
end
