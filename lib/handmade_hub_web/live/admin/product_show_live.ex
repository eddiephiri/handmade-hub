defmodule HandmadeHubWeb.Admin.ProductShowLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Catalog, Audit}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    product = Catalog.get_product!(id)
    {:ok,
     assign(socket,
       product: product,
       status: product.approval_status,
       category_form: to_form(%{"category" => product.category || ""}),
       confirming_action: nil
     )}
  end

  def handle_event("confirm_set_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, confirming_action: %{action: "set_status", status: status})}
  end

  def handle_event("confirm_remove", _params, socket) do
    {:noreply, assign(socket, confirming_action: %{action: "remove"})}
  end

  def handle_event("clear_confirmation", _params, socket) do
    {:noreply, assign(socket, confirming_action: nil)}
  end

  @impl true
  def handle_event("set_status", %{"status" => status}, socket) do
    product = socket.assigns.product
    result =
      case status do
        "approved" -> Catalog.approve_product(product)
        "rejected" -> Catalog.reject_product(product)
        _ -> {:ok, product}
      end

    case result do
      {:ok, updated} ->
        _ = Audit.log_admin_action(
          admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
          target_user_id: updated.artisan_id,
          action: "product_status_changed",
          metadata: %{product_id: updated.id, status: status}
        )
        {:noreply, assign(socket, product: updated, status: status, confirming_action: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update status") |> assign(confirming_action: nil)}
    end
  end

  def handle_event("save_category", %{"product" => %{"category" => category}}, socket) do
    case Catalog.update_product(socket.assigns.product, %{category: category}) do
      {:ok, updated} ->
        _ = Audit.log_admin_action(
          admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
          target_user_id: updated.artisan_id,
          action: "product_category_updated",
          metadata: %{product_id: updated.id, category: category}
        )
        {:noreply, assign(socket, product: updated, category_form: to_form(%{"category" => category}))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update category")}
    end
  end

  def handle_event("remove", _params, socket) do
    case Catalog.remove_product(socket.assigns.product) do
      {:ok, updated} ->
        _ = Audit.log_admin_action(
          admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
          target_user_id: updated.artisan_id,
          action: "product_removed",
          metadata: %{product_id: updated.id}
        )
        {:noreply, push_navigate(assign(socket, product: updated, confirming_action: nil), to: ~p"/admin/products")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove product") |> assign(confirming_action: nil)}
    end
  end
end
