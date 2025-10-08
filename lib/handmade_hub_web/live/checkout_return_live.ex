defmodule HandmadeHubWeb.CheckoutReturnLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Orders

  @impl true
  def mount(%{"order_id" => order_id} = params, _session, socket) do
    order = Orders.get_order!(order_id)

    # Check if payment has been verified via callback
    socket =
      case order.payment_status do
        "paid" ->
          socket
          |> assign(:order, order)
          |> assign(:payment_status, "completed")
          |> assign(:page_title, "Payment Complete")
          |> put_flash(:info, "Payment successful! Your order has been placed.")

        "pending" ->
          # Payment not yet confirmed, show verifying message
          socket
          |> assign(:order, order)
          |> assign(:payment_status, "verifying")
          |> assign(:page_title, "Verifying Payment")
          |> put_flash(:info, "We are verifying your payment. This should complete shortly.")

        _ ->
          socket
          |> assign(:order, order)
          |> assign(:payment_status, "failed")
          |> assign(:page_title, "Payment Issue")
          |> put_flash(:error, "There was an issue with your payment. Please contact support.")
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-16 px-4">
      <h1 class="text-2xl font-bold text-gray-900 mb-4">Payment Status</h1>

      <%= if @payment_status == "completed" do %>
        <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
          <p class="text-green-800">
            ✓ Payment successful! Your order <span class="font-semibold">#<%= @order.order_number %></span> has been confirmed.
          </p>
        </div>
        <div class="mt-6">
          <.link navigate={~p"/orders/#{@order.id}"} class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700">View Order</.link>
        </div>
      <% end %>

      <%= if @payment_status == "verifying" do %>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <p class="text-blue-800">
            ⏳ We are verifying your payment for order <span class="font-semibold">#<%= @order.order_number %></span>.
          </p>
          <p class="text-blue-700 text-sm mt-2">This usually takes a few moments. Please refresh this page in a minute.</p>
        </div>
        <div class="mt-6 flex gap-3">
          <button onclick="window.location.reload()" class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700">Refresh Page</button>
          <.link navigate={~p"/orders/#{@order.id}"} class="bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200">View Order</.link>
        </div>
      <% end %>

      <%= if @payment_status == "failed" do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
          <p class="text-red-800">
            ✗ There was an issue processing your payment for order <span class="font-semibold">#<%= @order.order_number %></span>.
          </p>
          <p class="text-red-700 text-sm mt-2">Please contact support for assistance.</p>
        </div>
        <div class="mt-6">
          <.link navigate={~p"/orders"} class="bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200">Go to My Orders</.link>
        </div>
      <% end %>
    </div>
    """
  end
end
