defmodule HandmadeHubWeb.Admin.ProductsLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Catalog, Audit}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", status: "pending", category: "", products: Catalog.list_products_for_admin(approval_status: "pending"), show_view_modal: false, selected_product: nil)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    products = Catalog.list_products_for_admin(search: q, approval_status: status_filter(socket.assigns.status), category: blank_to_nil(socket.assigns.category))
    {:noreply, assign(socket, search: q, products: products)}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    products = Catalog.list_products_for_admin(search: socket.assigns.search, approval_status: status_filter(status), category: blank_to_nil(socket.assigns.category))
    {:noreply, assign(socket, status: status, products: products)}
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    products = Catalog.list_products_for_admin(search: socket.assigns.search, approval_status: status_filter(socket.assigns.status), category: blank_to_nil(category))
    {:noreply, assign(socket, category: category, products: products)}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:ok, product} = Catalog.approve_product(product)
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: product.artisan_id, action: "product_approved", metadata: %{product_id: product.id})
    {:noreply, refresh(socket) |> assign(show_view_modal: false, selected_product: nil)}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:ok, product} = Catalog.reject_product(product)
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: product.artisan_id, action: "product_rejected", metadata: %{product_id: product.id})
    {:noreply, refresh(socket) |> assign(show_view_modal: false, selected_product: nil)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:ok, product} = Catalog.remove_product(product)
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: product.artisan_id, action: "product_removed", metadata: %{product_id: product.id})
    {:noreply, refresh(socket) |> assign(show_view_modal: false, selected_product: nil)}
  end

  def handle_event("view_product", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:noreply, assign(socket, show_view_modal: true, selected_product: product)}
  end

  def handle_event("close_view_modal", _params, socket) do
    {:noreply, assign(socket, show_view_modal: false, selected_product: nil)}
  end

  defp refresh(socket) do
    products = Catalog.list_products_for_admin(search: socket.assigns.search, approval_status: status_filter(socket.assigns.status), category: blank_to_nil(socket.assigns.category))
    assign(socket, products: products)
  end

  defp status_filter("all"), do: nil
  defp status_filter(status), do: status
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v
end
