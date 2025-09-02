defmodule HandmadeHubWeb.BrowseLive.Index do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.CoreComponents

  alias HandmadeHub.Catalog
  alias HandmadeHub.Shopping


  @impl true
  def mount(_params, session, socket) do
    products = Catalog.list_all_products_with_artisans()
    cart = get_or_create_cart(socket, session)
    cart_item_count = if cart, do: Shopping.get_cart_item_count(cart.id), else: 0

    {:ok, assign(socket,
      filtered_products: products,
      all_products: products,
      search_query: "",
      current_user: socket.assigns[:current_user],
      view_mode: :grid,
      selected_category: nil,
      sort_by: "newest",
      show_filters: false,
      show_product_modal: false,
      selected_product: nil,
      page_title: "Browse Products",
      cart: cart,
      cart_item_count: cart_item_count
    )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered_products = filter_products(socket.assigns.all_products, query, socket.assigns.selected_category, socket.assigns.sort_by)

    {:noreply, assign(socket,
      filtered_products: filtered_products,
      search_query: query
    )}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    filtered_products = filter_products(socket.assigns.all_products, "", socket.assigns.selected_category, socket.assigns.sort_by)

    {:noreply, assign(socket,
      filtered_products: filtered_products,
      search_query: ""
    )}
  end

  @impl true
  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == :grid, do: :list, else: :grid
    {:noreply, assign(socket, view_mode: new_mode)}
  end

  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, show_filters: !socket.assigns.show_filters)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    selected_category = if category == "all", do: nil, else: category
    filtered_products = filter_products(socket.assigns.all_products, socket.assigns.search_query, selected_category, socket.assigns.sort_by)

    {:noreply, assign(socket,
      filtered_products: filtered_products,
      selected_category: selected_category
    )}
  end

  @impl true
  def handle_event("sort_products", %{"sort" => sort_by}, socket) do
    filtered_products = filter_products(socket.assigns.all_products, socket.assigns.search_query, socket.assigns.selected_category, sort_by)

    {:noreply, assign(socket,
      filtered_products: filtered_products,
      sort_by: sort_by
    )}
  end

  @impl true
  def handle_event("view_product", %{"id" => id}, socket) do
    product = Enum.find(socket.assigns.all_products, &(&1.id == String.to_integer(id)))
    {:noreply, assign(socket, show_product_modal: true, selected_product: product)}
  end

  @impl true
  def handle_event("close_product_modal", _params, socket) do
    {:noreply, assign(socket, show_product_modal: false, selected_product: nil)}
  end

  @impl true
  def handle_event("contact_artisan", %{"artisan_id" => _artisan_id}, socket) do
    # Handle contact artisan functionality
    # You can redirect to a message page or show a contact modal
    {:noreply, put_flash(socket, :info, "Contact feature coming soon!")}
  end

  @impl true
  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    product_id = String.to_integer(product_id)
    
    case Shopping.add_to_cart(socket.assigns.cart.id, product_id, 1) do
      {:ok, _item} ->
        cart_item_count = Shopping.get_cart_item_count(socket.assigns.cart.id)
        {:noreply, 
         socket
         |> assign(:cart_item_count, cart_item_count)
         |> put_flash(:info, "Product added to cart")}
      
      {:error, :insufficient_stock} ->
        {:noreply, put_flash(socket, :error, "Not enough stock available")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add product to cart")}
    end
  end

  # Private helper functions
  defp filter_products(products, query, category, sort_by) do
    products
    |> filter_by_search(query)
    |> filter_by_category(category)
    |> sort_products(sort_by)
  end

  defp filter_by_search(products, ""), do: products
  defp filter_by_search(products, query) do
    query_lower = String.downcase(query)
    Enum.filter(products, fn product ->
      artisan_name = if product.artisan && product.artisan.name, do: product.artisan.name, else: ""
      String.contains?(String.downcase(product.name), query_lower) or
      String.contains?(String.downcase(product.description || ""), query_lower) or
      String.contains?(String.downcase(artisan_name), query_lower)
    end)
  end

  defp filter_by_category(products, nil), do: products
  defp filter_by_category(products, category) do
    Enum.filter(products, fn product ->
      product.category == category
    end)
  end

  defp sort_products(products, "newest") do
    Enum.sort_by(products, & &1.inserted_at, {:desc, DateTime})
  end

  defp sort_products(products, "oldest") do
    Enum.sort_by(products, & &1.inserted_at, {:asc, DateTime})
  end

  defp sort_products(products, "price_low") do
    Enum.sort_by(products, & &1.price, :asc)
  end

  defp sort_products(products, "price_high") do
    Enum.sort_by(products, & &1.price, :desc)
  end

  defp sort_products(products, "name") do
    Enum.sort_by(products, & String.downcase(&1.name), :asc)
  end

  defp sort_products(products, _), do: products

  defp get_unique_categories(products) do
    products
    |> Enum.map(& &1.category)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp get_product_image(product) do
    cond do
      # Use primary image if available
      is_list(product.product_images) and product.product_images != [] ->
        case Enum.find(product.product_images, & &1.is_primary) do
          nil -> product.product_images |> List.first() |> Map.get(:image_url)
          img -> img.image_url
        end

      # Fallback to old image field
      product.image != nil and product.image != "" ->
        product.image

      # Default placeholder
      true ->
        "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop"
    end
  end
  
  defp get_or_create_cart(socket, session) do
    user_id = if socket.assigns[:current_user], do: socket.assigns.current_user.id, else: nil
    session_id = Map.get(session, "session_uuid", generate_session_id())
    
    case Shopping.get_or_create_cart(user_id, session_id) do
      {:ok, cart} -> cart
      _ -> nil
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
