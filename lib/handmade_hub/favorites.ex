defmodule HandmadeHub.Favorites do
  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Favorites.Favorite

  def add_favorite(user_id, product_id) do
    %Favorite{}
    |> Favorite.changeset(%{user_id: user_id, product_id: product_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def remove_favorite(user_id, product_id) do
    from(f in Favorite, where: f.user_id == ^user_id and f.product_id == ^product_id)
    |> Repo.delete_all()
    :ok
  end

  def list_favorite_product_ids(user_id) do
    Repo.all(from f in Favorite, where: f.user_id == ^user_id, select: f.product_id)
  end

  def favorite_count(product_id) do
    Repo.one(from f in Favorite, where: f.product_id == ^product_id, select: count(f.id)) || 0
  end
end
