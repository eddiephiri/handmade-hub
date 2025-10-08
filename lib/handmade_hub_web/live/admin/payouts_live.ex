defmodule HandmadeHubWeb.Admin.PayoutsLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Payments
  alias HandmadeHub.Payments.PayoutScheduler
  import HandmadeHubWeb.FormatHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Artisan Payouts")
     |> assign(:filter_status, nil)
     |> assign(:selected_artisan_id, nil)
     |> load_payouts()}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    filter_status = if status == "", do: nil, else: status
    {:noreply, socket |> assign(:filter_status, filter_status) |> load_payouts()}
  end

  @impl true
  def handle_event("trigger_manual_payout", %{"artisan_id" => artisan_id}, socket) do
    case PayoutScheduler.process_manual_payout(String.to_integer(artisan_id)) do
      {:ok, _payout} ->
        {:noreply,
         socket
         |> put_flash(:info, "Payout initiated successfully")
         |> load_payouts()}

      {:error, :below_minimum} ->
        {:noreply, put_flash(socket, :error, "Artisan earnings below minimum payout amount")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate payout")}
    end
  end

  @impl true
  def handle_event("process_scheduled", _params, socket) do
    case PayoutScheduler.process_scheduled_payouts() do
      {:ok, results} ->
        {:noreply,
         socket
         |> put_flash(:info, "Scheduled payouts processed: #{results.successful} successful, #{results.failed} failed")
         |> load_payouts()}

      _ ->
        {:noreply, put_flash(socket, :info, "Payout processing completed")}
    end
  end

  defp load_payouts(socket) do
    filters = %{
      status: socket.assigns[:filter_status]
    }

    payouts = Payments.list_payouts(filters)
    assign(socket, :payouts, payouts)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto p-6">
      <div class="mb-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-slate-800">Artisan Payouts</h1>
            <p class="text-slate-600 mt-1">Manage and monitor payouts to artisans</p>
          </div>
          <button
            phx-click="process_scheduled"
            class="inline-flex items-center px-4 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-medium rounded-lg shadow-sm transition-colors"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            Run Scheduled Payouts
          </button>
        </div>
      </div>

      <!-- Filters -->
      <div class="flex items-center gap-3 mb-6">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
          <select phx-change="filter_status" name="status" class="rounded-md border-slate-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm">
            <option value="">All Statuses</option>
            <option value="pending" selected={@filter_status == "pending"}>Pending</option>
            <option value="processing" selected={@filter_status == "processing"}>Processing</option>
            <option value="completed" selected={@filter_status == "completed"}>Completed</option>
            <option value="failed" selected={@filter_status == "failed"}>Failed</option>
          </select>
        </div>
      </div>

      <!-- Payouts Table -->
      <div class="bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
        <table class="w-full">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                ID
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Artisan
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Period
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Gross Amount
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Platform Fee
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Net Amount
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Date
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200">
            <%= for payout <- @payouts do %>
              <tr class="hover:bg-slate-50 transition-colors">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-slate-900">
                  #<%= payout.id %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-900">
                  <%= if payout.artisan do %>
                    <.link navigate={~p"/admin/artisans/#{payout.artisan_id}"} class="text-indigo-600 hover:text-indigo-900 font-medium">
                      <%= payout.artisan.name || payout.artisan.email %>
                    </.link>
                  <% else %>
                    Artisan #<%= payout.artisan_id %>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                  <%= payout.payment_period %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-900">
                  <%= format_currency(payout.amount) %> <%= payout.currency %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                  <%= format_currency(payout.platform_fee) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-slate-900">
                  <%= format_currency(payout.net_amount) %> <%= payout.currency %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "px-2.5 py-1 text-xs font-medium rounded-full",
                    payout.status == "completed" && "bg-green-50 text-green-700",
                    payout.status == "processing" && "bg-blue-50 text-blue-700",
                    payout.status == "pending" && "bg-yellow-50 text-yellow-700",
                    payout.status == "failed" && "bg-red-50 text-red-700"
                  ]}>
                    <%= String.capitalize(payout.status) %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                  <%= if payout.completed_at do %>
                    <%= Calendar.strftime(payout.completed_at, "%Y-%m-%d") %>
                  <% else %>
                    <%= Calendar.strftime(payout.scheduled_date || payout.inserted_at, "%Y-%m-%d") %>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if Enum.empty?(@payouts) do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-slate-900">No payouts found</h3>
            <p class="mt-1 text-sm text-slate-500">
              <%= if @filter_status, do: "Try adjusting your filters", else: "Payouts will appear here when they are created" %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
