defmodule HandmadeHub.Orders.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_items" do
    field :product_name, :string
    field :product_price, :decimal
    field :quantity, :integer
    field :subtotal, :decimal
    
    belongs_to :order, HandmadeHub.Orders.Order
    belongs_to :product, HandmadeHub.Catalog.Product
    
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:order_id, :product_id, :product_name, :product_price, :quantity, :subtotal])
    |> validate_required([:product_name, :product_price, :quantity, :subtotal])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:product_price, greater_than_or_equal_to: 0)
    |> validate_number(:subtotal, greater_than_or_equal_to: 0)
  end

  @doc """
  Calculates subtotal for an order item
  """
  def calculate_subtotal(price, quantity) do
    Decimal.mult(price || Decimal.new("0"), Decimal.new(quantity || 0))
  end
end
