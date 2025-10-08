defmodule HandmadeHubWeb.Admin.OrdersLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Orders, Payments, Audit}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", status: "", payment_status: "", orders: Orders.list_orders_admin())}
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
         |> refresh()}

      {:error, reason_msg} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate refund: #{reason_msg}")}
    end
  end

  defp refresh(socket) do
    orders = Orders.list_orders_admin(%{search: socket.assigns.search, status: blank(socket.assigns.status), payment_status: blank(socket.assigns.payment_status)})
    assign(socket, orders: orders)
  end

  defp blank(""), do: nil
  defp blank(v), do: v
end
