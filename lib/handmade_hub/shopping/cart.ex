defmodule HandmadeHub.Shopping.Cart do
  use Ecto.Schema
  import Ecto.Changeset

  schema "carts" do
    field :session_id, :string
    field :status, :string, default: "active"
    
    belongs_to :user, HandmadeHub.Accounts.User
    has_many :cart_items, HandmadeHub.Shopping.CartItem
    
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cart, attrs) do
    cart
    |> cast(attrs, [:user_id, :session_id, :status])
    |> validate_required([:status])
    |> validate_inclusion(:status, ["active", "abandoned", "converted"])
  end
end
