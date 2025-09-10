defmodule HandmadeHub.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Accounts.User

  alias HandmadeHub.Catalog.Product
  alias HandmadeHub.Catalog.ProductImage

  @doc """
  Returns the list of products.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

  """
  def list_products do
    Repo.all(Product)
  end

  @doc """
  Returns the list of products for a given user.
  """
  def list_user_products(user_id) do
    Repo.all(
      from p in Product,
      where: p.artisan_id == ^user_id,
      preload: [:artisan, :product_images], # Make sure to preload product_images
      order_by: [desc: p.inserted_at]
    )
  end

  @doc """
  List all products with artisan info (for public browsing)
  """
  def list_all_products_with_artisans do
    Repo.all(
      from p in Product,
        join: a in assoc(p, :artisan),
        where: is_nil(p.removed_at) and p.approval_status == "approved",
        preload: [:artisan, :product_images],
        select: p
    )
  end

  @doc """
  List products by a list of ids with artisan and images preloaded.
  """
  def list_products_by_ids(product_ids) when is_list(product_ids) and length(product_ids) > 0 do
    Repo.all(
      from p in Product,
        where: p.id in ^product_ids,
        preload: [:artisan, :product_images],
        order_by: [desc: p.inserted_at]
    )
  end
  def list_products_by_ids(_), do: []

  @doc """
  Gets a single product.

  Raises `Ecto.NoResultsError` if the Product does not exist.

  ## Examples

      iex> get_product!(123)
      %Product{}

      iex> get_product!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(id) do
    Repo.get!(Product, id)
    |> Repo.preload([:artisan, :product_images])
  end

  @doc """
  Get single product with artisan info
  """
  def get_product_with_artisan!(id) do
    query = from p in Product,
      join: a in User, on: p.artisan_id == a.id,
      where: p.id == ^id,
      select: %{p | artisan: a}

    Repo.one!(query)
  end

  @doc """
  Creates a product.

  ## Examples

      iex> create_product(%{field: value})
      {:ok, %Product{}}

      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product.

  ## Examples

      iex> update_product(product, %{field: new_value})
      {:ok, %Product{}}

      iex> update_product(product, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.

  ## Examples

      iex> delete_product(product)
      {:ok, %Product{}}

      iex> delete_product(product)
      {:error, %Ecto.Changeset{}}

  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product changes.

  ## Examples

      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}

  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  # List products for a specific artisan (for artisan dashboard)
  def list_products_by_artisan(artisan_id) do
    Repo.all(from p in Product, where: p.artisan_id == ^artisan_id and is_nil(p.removed_at), order_by: [desc: p.inserted_at])
  end

  # Product Images
  def create_product_image(attrs \\ %{}) do
    %ProductImage{}
    |> ProductImage.changeset(attrs)
    |> Repo.insert()
  end

  def list_product_images(nil), do: []

  def list_product_images(product_id) do
    Repo.all(from i in ProductImage, where: i.product_id == ^product_id, order_by: [desc: i.is_primary, asc: i.inserted_at])
  end

  def set_primary_product_image(product_id, image_id) do
    Repo.transaction(fn ->
      # Set all images for this product to not primary
      from(i in ProductImage, where: i.product_id == ^product_id)
      |> Repo.update_all(set: [is_primary: false])
      # Set the selected image as primary
      image = Repo.get!(ProductImage, image_id)
      image
      |> ProductImage.changeset(%{is_primary: true})
      |> Repo.update()
    end)
  end

  def delete_product_image(image_id) do
    image = Repo.get!(ProductImage, image_id)
    Repo.delete(image)
  end

  # Admin analytics helper
  def count_products do
    Repo.aggregate(Product, :count)
  end

  # Admin product moderation helpers
  def list_products_for_admin(opts \\ []) do
    search = Keyword.get(opts, :search)
    status = Keyword.get(opts, :approval_status)
    category = Keyword.get(opts, :category)

    Product
    |> where([p], is_nil(p.removed_at))
    |> then(fn q -> if status, do: where(q, [p], p.approval_status == ^status), else: q end)
    |> then(fn q -> if category, do: where(q, [p], p.category == ^category), else: q end)
    |> then(fn q ->
      if search && search != "" do
        where(q, [p], ilike(p.name, ^"%#{search}%") or ilike(p.description, ^"%#{search}%"))
      else
        q
      end
    end)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
    |> Repo.preload([:artisan, :product_images])
  end

  def approve_product(%Product{} = product) do
    product
    |> Product.changeset(%{approval_status: "approved"})
    |> Repo.update()
  end

  def reject_product(%Product{} = product) do
    product
    |> Product.changeset(%{approval_status: "rejected"})
    |> Repo.update()
  end

  def remove_product(%Product{} = product) do
    product
    |> Product.changeset(%{removed_at: DateTime.utc_now()})
    |> Repo.update()
  end
end
