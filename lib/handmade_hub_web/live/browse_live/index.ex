defmodule HandmadeHubWeb.BrowseLive.Index do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Catalog

  def mount(_params, _session, socket) do
    products = Catalog.list_all_products_with_artisans()
    {:ok,
      assign(socket,
        filtered_products: products,
        search_query: "",
        current_user: socket.assigns[:current_user]
      )
    }
  end

  def handle_event("search", %{"query" => query}, socket) do
    products = Catalog.list_all_products_with_artisans()
    filtered = Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), String.downcase(query)) or
      String.contains?(String.downcase(product.description || ""), String.downcase(query))
    end)
    {:noreply, assign(socket, filtered_products: filtered, search_query: query)}
  end

  def handle_event("clear_search", _params, socket) do
    products = Catalog.list_all_products_with_artisans()
    {:noreply, assign(socket, filtered_products: products, search_query: "")}
  end
end
