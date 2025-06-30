defmodule HandmadeHub.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :description, :string
    field :image, :string
    field :price, :decimal
    field :quantity, :integer
    field :artisan_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :price, :quantity, :image])
    |> validate_required([:name, :description, :price, :quantity, :image])
  end
end
