defmodule HandmadeHubWeb.OrderLive.Show do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

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
         |> assign(:show_artisan_sidebar, true)
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

  defp apply_action(socket, :show, %{"id" => _id}) do
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

  def shipping_address_lines(nil), do: []

  def shipping_address_lines(address) do
    [
      address.address_line_1,
      address.address_line_2,
      city_province_line(address),
      address.postal_code,
      address.country
    ]
    |> Enum.reject(&blank?/1)
  end

  def present?(value), do: not blank?(value)

  defp city_province_line(address) do
    line =
      [address.city, address.province]
      |> Enum.reject(&blank?/1)
      |> Enum.join(", ")

    if line == "", do: nil, else: line
  end

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(nil), do: true
  defp blank?(_), do: false

  ## Delivery Tracking Helpers

  @doc """
  Checks if an order has a delivery assignment.
  """
  def has_delivery_assignment?(order) do
    not is_nil(order.delivery_assignment) and not is_nil(order.delivery_assignment.rider)
  end

  @doc """
  Gets the delivery status color for styling.
  """
  def get_delivery_status_color(status) do
    case status do
      "dispatched" -> "bg-blue-100 text-blue-800"
      "in_transit" -> "bg-indigo-100 text-indigo-800"
      "delivered" -> "bg-green-100 text-green-800"
      "failed" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  @doc """
  Gets the delivery status icon.
  """
  def get_delivery_status_icon(status) do
    case status do
      "dispatched" -> "📦"
      "in_transit" -> "🚚"
      "delivered" -> "✅"
      "failed" -> "❌"
      _ -> "📋"
    end
  end

  @doc """
  Formats a phone number for display and ensures it's in the correct format for tel: links.
  Handles both formats: 0977123456 and 260977123456
  """
  def format_rider_phone(phone_number) when is_binary(phone_number) do
    # Remove any spaces or dashes
    cleaned = phone_number
              |> String.replace(~r/[\s-]/, "")
              |> String.trim()

    # If it starts with 260, keep it; if it starts with 0, replace with 260
    cond do
      String.starts_with?(cleaned, "260") -> cleaned
      String.starts_with?(cleaned, "0") and String.length(cleaned) > 1 ->
        "260" <> String.slice(cleaned, 1..-1)
      true -> cleaned
    end
  end

  def format_rider_phone(nil), do: nil

  @doc """
  Gets delivery timeline events based on assignment status.
  """
  def get_delivery_timeline_events(order) do
    case order.delivery_assignment do
      nil -> []
      assignment ->
        events = []

        # Rider assigned event
        events = events ++ [%{
          title: "Rider Assigned",
          description: "A delivery rider has been assigned to your order",
          timestamp: assignment.inserted_at,
          completed: true,
          icon: "👤"
        }]

        # Status-specific events
        events = case assignment.status do
          "dispatched" ->
            events ++ [%{
              title: "Dispatched",
              description: "Your order is ready for pickup",
              timestamp: assignment.updated_at,
              completed: true,
              icon: "📦"
            }]

          "in_transit" ->
            events ++ [
              %{
                title: "Dispatched",
                description: "Your order is ready for pickup",
                timestamp: assignment.inserted_at,
                completed: true,
                icon: "📦"
              },
              %{
                title: "In Transit",
                description: "Your order is on the way to you",
                timestamp: assignment.updated_at,
                completed: true,
                icon: "🚚"
              }
            ]

          "delivered" ->
            events ++ [
              %{
                title: "Dispatched",
                description: "Your order is ready for pickup",
                timestamp: assignment.inserted_at,
                completed: true,
                icon: "📦"
              },
              %{
                title: "In Transit",
                description: "Your order is on the way to you",
                timestamp: assignment.inserted_at,
                completed: true,
                icon: "🚚"
              },
              %{
                title: "Delivered",
                description: "Your order has been successfully delivered",
                timestamp: assignment.updated_at,
                completed: true,
                icon: "✅"
              }
            ]

          "failed" ->
            events ++ [%{
              title: "Delivery Failed",
              description: assignment.notes || "Delivery attempt was unsuccessful",
              timestamp: assignment.updated_at,
              completed: true,
              icon: "❌"
            }]

          _ -> events
        end

        events
    end
  end

  @doc """
  Gets a human-readable delivery status description.
  """
  def get_delivery_status_description(status) do
    case status do
      "dispatched" -> "Your order has been assigned to a delivery rider and is ready for pickup"
      "in_transit" -> "Your order is on the way to your delivery address"
      "delivered" -> "Your order has been successfully delivered"
      "failed" -> "The delivery attempt was unsuccessful. Please contact support for assistance"
      _ -> "Delivery status unknown"
    end
  end
end
