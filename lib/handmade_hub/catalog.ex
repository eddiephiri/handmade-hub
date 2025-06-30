defmodule HandmadeHub.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Accounts.User

  alias HandmadeHub.Catalog.Product

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
    Repo.all(from p in Product, where: p.artisan_id == ^user_id)
  end

  @doc """
  List all products with artisan info (for public browsing)
  """
  def list_all_products_with_artisans do
    query = from p in Product,
      join: a in User, on: p.artisan_id == a.id,
      where: p.quantity > 0,
      select: %{p | artisan: a},
      order_by: [desc: p.inserted_at]

    Repo.all(query)
  end

  @doc """
  Gets a single product.

  Raises `Ecto.NoResultsError` if the Product does not exist.

  ## Examples

      iex> get_product!(123)
      %Product{}

      iex> get_product!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(id), do: Repo.get!(Product, id)

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
    Repo.all(from p in Product, where: p.artisan_id == ^artisan_id, order_by: [desc: p.inserted_at])
  end
end
