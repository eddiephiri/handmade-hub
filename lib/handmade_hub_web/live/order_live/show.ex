defmodule HandmadeHubWeb.OrderLive.Show do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Orders
  alias HandmadeHub.Catalog

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if socket.assigns.current_user do
      order = Orders.get_order!(id)
      
      # Verify the order belongs to the current user
      if order.user_id == socket.assigns.current_user.id do
        {:ok,
         socket
         |> assign(:page_title, "Order ##{order.order_number}")
         |> assign(:order, order)
         |> load_order_items_with_products(order)}
      else
        {:ok,
         socket
         |> put_flash(:error, "Order not found")
         |> redirect(to: ~p"/orders")}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to view order details")
       |> redirect(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Order Details")
  end

  @impl true
  def handle_event("cancel_order", _params, socket) do
    case Orders.cancel_order(socket.assigns.order.id) do
      {:ok, order} ->
        {:noreply,
         socket
         |> assign(:order, order)
         |> put_flash(:info, "Order has been cancelled successfully")}
      
      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("track_order", _params, socket) do
    # This would integrate with a shipping provider API
    # For now, we'll just show a message
    {:noreply, put_flash(socket, :info, "Tracking information will be available soon")}
  end

  defp load_order_items_with_products(socket, order) do
    # Load product details for each order item
    order_items_with_products = 
      Enum.map(order.order_items, fn item ->
        product = Catalog.get_product!(item.product_id)
        Map.put(item, :product, product)
      end)
    
    assign(socket, :order_items_with_products, order_items_with_products)
  end


  def format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def format_date_short(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
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

  def get_payment_status_color(status) do
    case status do
      "pending" -> "bg-yellow-100 text-yellow-800"
      "paid" -> "bg-green-100 text-green-800"
      "failed" -> "bg-red-100 text-red-800"
      "refunded" -> "bg-purple-100 text-purple-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  def get_status_icon(status) do
    case status do
      "pending" -> "🕐"
      "processing" -> "⚙️"
      "shipped" -> "📦"
      "delivered" -> "✅"
      "cancelled" -> "❌"
      _ -> "📋"
    end
  end

  def can_cancel_order?(order) do
    order.status in ["pending", "processing"]
  end

  def get_timeline_events(order) do
    events = [
      %{
        title: "Order Placed",
        description: "Your order has been received",
        timestamp: order.inserted_at,
        completed: true,
        icon: "📝"
      }
    ]

    events = if order.payment_status == "paid" do
      events ++ [%{
        title: "Payment Confirmed",
        description: "Payment has been successfully processed",
        timestamp: order.updated_at,
        completed: true,
        icon: "💳"
      }]
    else
      events
    end

    events = case order.status do
      status when status in ["processing", "shipped", "delivered"] ->
        events ++ [%{
          title: "Order Processing",
          description: "Your order is being prepared",
          timestamp: order.updated_at,
          completed: true,
          icon: "⚙️"
        }]
      _ -> events
    end

    events = case order.status do
      status when status in ["shipped", "delivered"] ->
        events ++ [%{
          title: "Order Shipped",
          description: "Your order is on the way",
          timestamp: order.updated_at,
          completed: true,
          icon: "🚚"
        }]
      _ -> events
    end

    events = case order.status do
      "delivered" ->
        events ++ [%{
          title: "Order Delivered",
          description: "Your order has been delivered",
          timestamp: order.updated_at,
          completed: true,
          icon: "✅"
        }]
      "cancelled" ->
        events ++ [%{
          title: "Order Cancelled",
          description: "Your order has been cancelled",
          timestamp: order.updated_at,
          completed: true,
          icon: "❌"
        }]
      _ -> events
    end

    events
  end
end
