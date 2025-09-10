defmodule HandmadeHub.Reviews.Review do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reviews" do
    field :rating, :integer
    field :comment, :string
    field :visible, :boolean, default: true
    field :flagged, :boolean, default: false

    belongs_to :user, HandmadeHub.Accounts.User
    belongs_to :product, HandmadeHub.Catalog.Product
    belongs_to :artisan, HandmadeHub.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:user_id, :product_id, :artisan_id, :rating, :comment, :visible, :flagged])
    |> validate_required([:user_id, :rating])
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> check_constraint(:product_id, name: :reviews_user_product_unique)
    |> check_constraint(:artisan_id, name: :reviews_user_artisan_unique)
  end
end
