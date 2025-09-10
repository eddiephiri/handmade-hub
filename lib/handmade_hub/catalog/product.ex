defmodule HandmadeHub.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :image, :string
    field :price, :decimal
    field :category, :string
    field :quantity, :integer
    field :description, :string
    field :approval_status, :string, default: "pending"
    field :removed_at, :utc_datetime
    belongs_to :artisan, HandmadeHub.Accounts.User, foreign_key: :artisan_id

    has_many :product_images, HandmadeHub.Catalog.ProductImage, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :price, :quantity, :image, :artisan_id, :category, :approval_status, :removed_at])
    |> validate_required([:name, :description, :price, :quantity, :artisan_id])
    |> validate_inclusion(:approval_status, ["pending", "approved", "rejected"])
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
    |> unique_constraint(:is_primary, name: :product_images_product_id_is_primary_index)
  end
end
