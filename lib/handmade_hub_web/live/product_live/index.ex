defmodule HandmadeHubWeb.ProductLive.Index do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.Catalog
  alias HandmadeHub.Catalog.Product

  @impl true
  def mount(_params, _session, socket) do
    # Restrict to artisans only
    if socket.assigns.current_user.role != "artisan" or socket.assigns.current_user.artisan_status != "approved" do
      {:halt, redirect(socket, to: ~p"/")}
    else
      {:ok, stream(socket, :products, Catalog.list_user_products(socket.assigns.current_user.id))}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  defp apply_action(socket, :show, %{"id" => _id}) do
    # This LiveView does not implement :show; redirect back to index
    socket
    |> push_navigate(to: ~p"/products")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    product = Catalog.get_product!(id)

    # Ensure artisan can only edit their own products
    if product.artisan_id != socket.assigns.current_user.id do
      socket
      |> put_flash(:error, "You can only edit your own products.")
      |> push_navigate(to: ~p"/products")
    else
      socket
      |> assign(:page_title, "Edit Product")
      |> assign(:product, product)
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Product")
    |> assign(:product, %Product{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Products")
    |> assign(:product, nil)
  end

  @impl true
  def handle_info({HandmadeHubWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    {:noreply, stream_insert(socket, :products, product)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)

    # Ensure artisan can only delete their own products
    if product.artisan_id != socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "You can only delete your own products.")}
    else
      {:ok, _} = Catalog.delete_product(product)
      {:noreply, stream_delete(socket, :products, product)}
    end
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
        "https://via.placeholder.com/400x400?text=No+Image"
    end
  end
end
