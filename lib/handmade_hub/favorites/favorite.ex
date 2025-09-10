defmodule HandmadeHub.Favorites.Favorite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "favorites" do
    belongs_to :user, HandmadeHub.Accounts.User
    belongs_to :product, HandmadeHub.Catalog.Product
    timestamps(type: :utc_datetime)
  end

  def changeset(favorite, attrs) do
    favorite
    |> cast(attrs, [:user_id, :product_id])
    |> validate_required([:user_id, :product_id])
    |> unique_constraint([:user_id, :product_id])
  end
end
