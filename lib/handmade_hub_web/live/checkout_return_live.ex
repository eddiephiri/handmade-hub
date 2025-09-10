defmodule HandmadeHubWeb.CheckoutReturnLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Orders

  @impl true
  def mount(%{"depositId" => _deposit_id, "order_id" => order_id}, _session, socket) do
    # In a real integration, verify deposit status via provider before marking paid
    case Orders.mark_order_as_paid(order_id, "PAWA-RETURN") do
      {:ok, order} ->
        {:ok,
         socket
         |> assign(:order, order)
         |> assign(:page_title, "Payment Complete")
         |> put_flash(:info, "Payment successful! Your order has been placed.")}
      {:error, _} ->
        {:ok, put_flash(socket, :error, "We could not verify your payment. Please contact support.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-16 px-4">
      <h1 class="text-2xl font-bold text-gray-900 mb-4">Payment Result</h1>
      <%= if @order do %>
        <p class="text-gray-700">Thank you! Your order <span class="font-semibold">#<%= @order.order_number %></span> has been confirmed.</p>
        <div class="mt-6">
          <.link navigate={~p"/orders/#{@order.id}"} class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700">View Order</.link>
        </div>
      <% else %>
        <p class="text-gray-700">We are validating your payment. You can refresh this page or check your orders shortly.</p>
        <div class="mt-6">
          <.link navigate={~p"/orders"} class="bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200">Go to My Orders</.link>
        </div>
      <% end %>
    </div>
    """
  end
end
