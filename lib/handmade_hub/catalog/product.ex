defmodule HandmadeHub.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :image, :string
    field :price, :decimal
    field :artisan_id, :id
    field :category, :string
    field :quantity, :integer
    field :description, :string
    field :artisan, :map, virtual: true

    has_many :product_images, HandmadeHub.Catalog.ProductImage, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :price, :quantity, :image, :artisan_id, :category])
    |> validate_required([:name, :description, :price, :quantity, :image, :artisan_id])
  end
end

defmodule HandmadeHub.Catalog.ProductImage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_images" do
    field :image_url, :string
    field :is_primary, :boolean, default: false
    belongs_to :product, HandmadeHub.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product_image, attrs) do
    product_image
    |> cast(attrs, [:image_url, :is_primary, :product_id])
    |> validate_required([:image_url, :product_id])
  end
end
