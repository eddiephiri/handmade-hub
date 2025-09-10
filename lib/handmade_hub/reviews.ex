defmodule HandmadeHub.Reviews do
  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Reviews.Review

  def create_product_review(user_id, product_id, rating, comment \\ nil) do
    %Review{}
    |> Review.changeset(%{user_id: user_id, product_id: product_id, rating: rating, comment: comment})
    |> Repo.insert()
  end

  def create_artisan_review(user_id, artisan_id, rating, comment \\ nil) do
    %Review{}
    |> Review.changeset(%{user_id: user_id, artisan_id: artisan_id, rating: rating, comment: comment})
    |> Repo.insert()
  end

  def list_product_reviews(product_id) do
    Repo.all(from r in Review, where: r.product_id == ^product_id and r.visible == true, order_by: [desc: r.inserted_at], preload: [:user])
  end

  def list_artisan_reviews(artisan_id) do
    Repo.all(from r in Review, where: r.artisan_id == ^artisan_id and r.visible == true, order_by: [desc: r.inserted_at], preload: [:user])
  end

  def average_product_rating(product_id) do
    Repo.one(from r in Review, where: r.product_id == ^product_id, select: avg(r.rating)) || 0.0
  end

  def average_artisan_rating(artisan_id) do
    Repo.one(from r in Review, where: r.artisan_id == ^artisan_id, select: avg(r.rating)) || 0.0
  end

  @doc """
  Returns all reviews for an artisan, including reviews left on the artisan's products.
  """
  def list_all_reviews_for_artisan(artisan_id) do
    direct = Repo.all(from r in Review, where: r.artisan_id == ^artisan_id and r.visible == true, preload: [:user])

    product_based =
      Repo.all(
        from r in Review,
          join: p in HandmadeHub.Catalog.Product,
          on: r.product_id == p.id,
          where: not is_nil(r.product_id) and p.artisan_id == ^artisan_id and r.visible == true,
          select: r,
          preload: [:user]
      )

    (direct ++ product_based)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  @doc """
  Returns the average rating for an artisan, including reviews left on their products.
  """
  def average_all_reviews_for_artisan(artisan_id) do
    reviews = list_all_reviews_for_artisan(artisan_id)
    case reviews do
      [] -> 0.0
      list -> Enum.sum(Enum.map(list, & &1.rating)) / length(list)
    end
  end

  def product_review_count(product_id) do
    Repo.one(from r in Review, where: r.product_id == ^product_id, select: count(r.id)) || 0
  end
end
