defmodule HandmadeHubWeb.Admin.TransactionsLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Payments
  import HandmadeHubWeb.FormatHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Payment Transactions")
     |> assign(:filter_type, nil)
     |> assign(:filter_status, nil)
     |> load_transactions()}
  end

  @impl true
  def handle_event("filter", %{"type" => type}, socket) do
    filter_type = if type == "", do: nil, else: type
    {:noreply, socket |> assign(:filter_type, filter_type) |> load_transactions()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    filter_status = if status == "", do: nil, else: status
    {:noreply, socket |> assign(:filter_status, filter_status) |> load_transactions()}
  end

  defp load_transactions(socket) do
    filters = %{
      type: socket.assigns[:filter_type],
      status: socket.assigns[:filter_status]
    }

    transactions = Payments.list_transactions(filters)
    assign(socket, :transactions, transactions)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto p-6">
      <div class="mb-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-slate-800">Payment Transactions</h1>
            <p class="text-slate-600 mt-1">View all pawaPay transactions including deposits, payouts, and refunds</p>
          </div>
        </div>
      </div>

      <!-- Filters -->
      <div class="flex items-center gap-3 mb-6">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Type</label>
          <select phx-change="filter" name="type" class="rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
            <option value="">All Types</option>
            <option value="deposit" selected={@filter_type == "deposit"}>Deposits</option>
            <option value="payout" selected={@filter_type == "payout"}>Payouts</option>
            <option value="refund" selected={@filter_type == "refund"}>Refunds</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
          <select phx-change="filter_status" name="status" class="rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
            <option value="">All Statuses</option>
            <option value="pending" selected={@filter_status == "pending"}>Pending</option>
            <option value="completed" selected={@filter_status == "completed"}>Completed</option>
            <option value="failed" selected={@filter_status == "failed"}>Failed</option>
            <option value="cancelled" selected={@filter_status == "cancelled"}>Cancelled</option>
          </select>
        </div>
      </div>

      <!-- Transactions Table -->
      <div class="bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
        <table class="w-full">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Transaction ID
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Type
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Amount
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Related
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Date
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200">
            <%= for transaction <- @transactions do %>
              <tr class="hover:bg-slate-50 transition-colors">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-slate-900">
                  <%= String.slice(transaction.transaction_id, 0..7) %>...
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "px-2.5 py-1 text-xs font-medium rounded-full",
                    transaction.transaction_type == "deposit" && "bg-blue-50 text-blue-700",
                    transaction.transaction_type == "payout" && "bg-purple-50 text-purple-700",
                    transaction.transaction_type == "refund" && "bg-orange-50 text-orange-700"
                  ]}>
                    <%= String.capitalize(transaction.transaction_type) %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-slate-900">
                  <%= format_currency(transaction.amount) %> <%= transaction.currency %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "px-2.5 py-1 text-xs font-medium rounded-full",
                    transaction.status == "completed" && "bg-green-50 text-green-700",
                    transaction.status == "pending" && "bg-yellow-50 text-yellow-700",
                    transaction.status == "failed" && "bg-red-50 text-red-700",
                    transaction.status == "cancelled" && "bg-slate-50 text-slate-700"
                  ]}>
                    <%= String.capitalize(transaction.status) %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                  <%= if transaction.order do %>
                    <.link navigate={~p"/admin/orders"} class="text-indigo-600 hover:text-indigo-900 font-medium">
                      Order #<%= transaction.order.order_number %>
                    </.link>
                  <% end %>
                  <%= if transaction.payout do %>
                    <.link navigate={~p"/admin/payouts"} class="text-indigo-600 hover:text-indigo-900 font-medium">
                      Payout #<%= transaction.payout_id %>
                    </.link>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                  <%= Calendar.strftime(transaction.inserted_at, "%Y-%m-%d %H:%M") %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if Enum.empty?(@transactions) do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-slate-900">No transactions found</h3>
            <p class="mt-1 text-sm text-slate-500">
              <%= if @filter_type || @filter_status, do: "Try adjusting your filters", else: "Transactions will appear here" %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
