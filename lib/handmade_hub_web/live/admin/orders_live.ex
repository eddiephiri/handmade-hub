defmodule HandmadeHubWeb.Admin.OrdersLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Orders, Payments, Audit, Delivery}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", status: "", payment_status: "", orders: Orders.list_orders_admin())
     |> assign(show_assign_modal: false, selected_order: nil, available_riders: [], confirming_refund: nil)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q, orders: Orders.list_orders_admin(%{search: q, status: blank(socket.assigns.status), payment_status: blank(socket.assigns.payment_status)}))}
  end

  def handle_event("filter", %{"status" => status, "payment_status" => payment_status}, socket) do
    {:noreply, assign(socket, status: status, payment_status: payment_status, orders: Orders.list_orders_admin(%{search: socket.assigns.search, status: blank(status), payment_status: blank(payment_status)}))}
  end

  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    {:ok, order} = Orders.update_order_status(id, status)
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: order.user_id, action: "order_status_updated", metadata: %{order_id: order.id, status: status})
    {:noreply, refresh(socket)}
  end

  def handle_event("update_payment_status", %{"id" => id, "payment_status" => payment_status}, socket) do
    {:ok, order} = Orders.update_order_payment_status(id, payment_status)
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: order.user_id, action: "order_payment_status_updated", metadata: %{order_id: order.id, payment_status: payment_status})
    {:noreply, refresh(socket)}
  end

  def handle_event("confirm_refund", %{"id" => id}, socket) do
    order = Orders.get_order!(id)
    {:noreply, assign(socket, confirming_refund: %{order_id: id, order: order})}
  end

  def handle_event("clear_refund_confirmation", _params, socket) do
    {:noreply, assign(socket, confirming_refund: nil)}
  end

  def handle_event("refund", %{"id" => id, "reason" => reason}, socket) do
    order = Orders.get_order!(id)

    case Payments.create_refund(order, order.total, reason) do
      {:ok, _transaction} ->
        _ = Audit.log_admin_action(
          admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
          target_user_id: order.user_id,
          action: "order_refund_initiated",
          metadata: %{order_id: order.id, amount: order.total, reason: reason}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Refund initiated successfully")
         |> assign(confirming_refund: nil)
         |> refresh()}

      {:error, reason_msg} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate refund: #{reason_msg}") |> assign(confirming_refund: nil)}
    end
  end

  @impl true
  def handle_event("open_assign_modal", %{"order_id" => order_id}, socket) do
    order = Orders.get_order!(order_id)
    riders = Delivery.list_active_riders()

    {:noreply,
     socket
     |> assign(show_assign_modal: true, selected_order: order, available_riders: riders)}
  end

  @impl true
  def handle_event("close_assign_modal", _params, socket) do
    {:noreply, assign(socket, show_assign_modal: false, selected_order: nil)}
  end

  @impl true
  def handle_event("assign_rider", %{"order_id" => order_id, "rider_id" => rider_id}, socket) do
    admin = socket.assigns.current_admin

    case Delivery.assign_order_to_rider(order_id, rider_id, admin.id) do
      {:ok, _assignment} ->
        _ = Audit.log_admin_action(
          admin_id: admin.id,
          action: "delivery_rider_assigned",
          metadata: %{order_id: order_id, rider_id: rider_id}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Rider assigned successfully")
         |> assign(show_assign_modal: false, selected_order: nil)
         |> refresh()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to assign rider")}
    end
  end

  defp refresh(socket) do
    orders = Orders.list_orders_admin(%{search: socket.assigns.search, status: blank(socket.assigns.status), payment_status: blank(socket.assigns.payment_status)})
    assign(socket, orders: orders)
  end

  defp blank(""), do: nil
  defp blank(v), do: v
end
