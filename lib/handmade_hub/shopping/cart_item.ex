defmodule HandmadeHub.Shopping.CartItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cart_items" do
    field :quantity, :integer, default: 1
    field :price, :decimal
    
    belongs_to :cart, HandmadeHub.Shopping.Cart
    belongs_to :product, HandmadeHub.Catalog.Product
    
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:cart_id, :product_id, :quantity, :price])
    |> validate_required([:cart_id, :product_id, :quantity, :price])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> unique_constraint([:cart_id, :product_id])
  end
end
