defmodule HandmadeHubWeb.BuyerDashboardLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.Orders
  alias HandmadeHub.Shopping
  alias HandmadeHub.Accounts
  alias HandmadeHub.Messaging

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    cond do
      is_nil(user) ->
        {:ok,
         socket
         |> put_flash(:error, "You must be logged in to access this page")
         |> redirect(to: ~p"/users/log_in")}

      user.role == "artisan" and user.artisan_status == "approved" ->
        {:ok,
         socket
         |> put_flash(:info, "Redirecting to your artisan dashboard")
         |> redirect(to: ~p"/artisan/dashboard")}

      true ->  # Default case - treat as buyer (including when role is "buyer" or nil)
        # Get buyer's recent orders
        recent_orders = Orders.list_user_orders(user.id) |> Enum.take(5)

        # Get cart information
        {:ok, cart} = Shopping.get_or_create_cart(user.id, nil)
        cart_item_count = Shopping.get_cart_item_count(cart.id)

        # Calculate statistics
        stats = calculate_buyer_stats(user.id)

        {:ok,
         socket
         |> assign(:page_title, "Buyer Dashboard")
         |> assign(:recent_orders, recent_orders)
         |> assign(:cart_item_count, cart_item_count)
         |> assign(:unread_messages, Messaging.unread_count(user.id))
         |> assign(:stats, stats)
         |> assign(:current_tab, :overview)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Buyer Dashboard")
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, String.to_atom(tab))}
  end

  @impl true
  def handle_event("cancel_order", %{"order_id" => order_id}, socket) do
    case Orders.cancel_order(order_id) do
      {:ok, _order} ->
        recent_orders = Orders.list_user_orders(socket.assigns.current_user.id) |> Enum.take(5)
        stats = calculate_buyer_stats(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Order cancelled successfully")
         |> assign(:recent_orders, recent_orders)
         |> assign(:stats, stats)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp calculate_buyer_stats(user_id) do
    orders = Orders.list_user_orders(user_id)

    %{
      total_orders: length(orders),
      pending_orders: Enum.count(orders, &(&1.status == "pending")),
      processing_orders: Enum.count(orders, &(&1.status == "processing")),
      delivered_orders: Enum.count(orders, &(&1.status == "delivered")),
      total_spent: calculate_total_spent(orders),
      favorite_category: get_favorite_category(orders)
    }
  end

  defp calculate_total_spent(orders) do
    orders
    |> Enum.filter(&(&1.payment_status == "paid"))
    |> Enum.reduce(Decimal.new("0"), fn order, acc ->
      Decimal.add(acc, order.total || Decimal.new("0"))
    end)
  end

  defp get_favorite_category(_orders) do
    # This would need more implementation to track product categories
    # For now, return a placeholder
    "Handmade Items"
  end


  def format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  def get_status_color(status) do
    case status do
      "pending" -> "bg-yellow-100 text-yellow-800"
      "processing" -> "bg-blue-100 text-blue-800"
      "shipped" -> "bg-indigo-100 text-indigo-800"
      "delivered" -> "bg-green-100 text-green-800"
      "cancelled" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
