defmodule HandmadeHubWeb.FavoritesLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.{Favorites, Catalog}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    fav_ids = Favorites.list_favorite_product_ids(user.id)
    products = Catalog.list_products_by_ids(fav_ids)
    {:ok, assign(socket, page_title: "My Favorites", products: products, favorite_product_ids: MapSet.new(fav_ids))}
  end

  @impl true
  def handle_event("toggle_favorite", %{"product_id" => product_id}, socket) do
    pid = String.to_integer(product_id)
    uid = socket.assigns.current_user.id
    favs = socket.assigns.favorite_product_ids
    case MapSet.member?(favs, pid) do
      true ->
        :ok = Favorites.remove_favorite(uid, pid)
        {:noreply,
         socket
         |> assign(:favorite_product_ids, MapSet.delete(favs, pid))
         |> assign(:products, Enum.reject(socket.assigns.products, &(&1.id == pid)))}
      false ->
        _ = Favorites.add_favorite(uid, pid)
        # Re-fetch this single product to append if desired; for simplicity, reload all
        fav_ids = Favorites.list_favorite_product_ids(uid)
        {:noreply, assign(socket, favorite_product_ids: MapSet.new(fav_ids), products: Catalog.list_products_by_ids(fav_ids))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">My Favorites</h1>
            <p class="text-gray-600">Products you have saved</p>
          </div>
          <.link navigate={~p"/browse"} class="inline-flex items-center text-indigo-600 hover:text-indigo-700">
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Browse
          </.link>
        </div>

        <%= if @products == [] do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center">
            <p class="text-gray-600">You have not added any favorites yet.</p>
            <div class="mt-4">
              <.link navigate={~p"/browse"} class="inline-flex items-center px-4 py-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700">Browse Products</.link>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
            <%= for product <- @products do %>
              <div class="bg-white rounded-lg border border-gray-100 shadow-sm overflow-hidden">
                <div class="relative aspect-square bg-gray-50">
                  <img src={product.image || (product.product_images |> List.first() |> then(&(&1 && &1.image_url)))} alt={product.name} class="w-full h-full object-cover" />
                  <button phx-click="toggle_favorite" phx-value-product_id={product.id} class="absolute top-3 right-3 bg-white/95 p-2 rounded-full shadow">
                    <svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M11.645 20.91l-.007-.003-.022-.012a15.247 15.247 0 01-.383-.218 25.18 25.18 0 01-4.244-3.17C4.688 15.238 2.25 12.533 2.25 9.375 2.25 6.94 4.243 5 6.563 5c1.36 0 2.636.613 3.487 1.746L12 8.25l1.95-1.504C14.8 5.613 16.076 5 17.437 5 19.757 5 21.75 6.94 21.75 9.375c0 3.158-2.438 5.863-4.739 8.032a25.18 25.18 0 01-4.244 3.17 15.247 15.247 0 01-.383.218l-.022.012-.007.003a.75.75 0 01-.666 0z" />
                    </svg>
                  </button>
                </div>
                <div class="p-4">
                  <h3 class="font-semibold text-gray-900 line-clamp-2"><%= product.name %></h3>
                  <p class="text-sm text-gray-600 line-clamp-2"><%= product.description %></p>
                  <div class="mt-3 flex items-center justify-between">
                    <span class="font-bold text-gray-900"><%= format_currency(product.price) %></span>
                    <.link navigate={~p"/browse/#{product.id}"} class="text-indigo-600 hover:text-indigo-700 text-sm font-medium">View</.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
