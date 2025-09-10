defmodule HandmadeHubWeb.OrderLive.Index do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.Orders
  alias HandmadeHub.Orders.Order

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      orders = Orders.list_user_orders(socket.assigns.current_user.id)

      {:ok,
       socket
       |> assign(:page_title, "My Orders")
       |> assign(:orders, orders)
       |> assign(:filter_status, "all")
       |> assign(:show_artisan_sidebar, true)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to view your orders")
       |> redirect(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Orders")
    |> assign(:order, nil)
  end

  @impl true
  def handle_event("filter_orders", %{"status" => status}, socket) do
    orders = filter_orders_by_status(socket.assigns.current_user.id, status)

    {:noreply,
     socket
     |> assign(:orders, orders)
     |> assign(:filter_status, status)}
  end

  defp filter_orders_by_status(user_id, "all") do
    Orders.list_user_orders(user_id)
  end

  defp filter_orders_by_status(user_id, status) do
    Orders.list_user_orders(user_id)
    |> Enum.filter(fn order -> order.status == status end)
  end


  def format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
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

  def get_progress_percentage(status) do
    case status do
      "pending" -> 25
      "processing" -> 50
      "shipped" -> 75
      "delivered" -> 100
      _ -> 0
    end
  end
end
