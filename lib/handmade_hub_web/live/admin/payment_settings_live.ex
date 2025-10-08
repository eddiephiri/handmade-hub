defmodule HandmadeHubWeb.Admin.PaymentSettingsLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Payments
  alias HandmadeHub.Payments.PayoutSettings

  @impl true
  def mount(_params, _session, socket) do
    # Restrict to super_admin only
    if socket.assigns.current_admin.role != "super_admin" do
      {:ok,
       socket
       |> put_flash(:error, "Only super admins can access payment settings")
       |> push_navigate(to: ~p"/admin/dashboard")}
    else
      settings = Payments.get_payout_settings()
      changeset = PayoutSettings.changeset(settings, %{})

      {:ok,
       socket
       |> assign(:page_title, "Payment Settings")
       |> assign(:settings, settings)
       |> assign(:changeset, changeset)
       |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate", %{"payout_settings" => params}, socket) do
    changeset =
      socket.assigns.settings
      |> PayoutSettings.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset) |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"payout_settings" => params}, socket) do
    case Payments.update_payout_settings(params) do
      {:ok, settings} ->
        changeset = PayoutSettings.changeset(settings, %{})

        {:noreply,
         socket
         |> assign(:settings, settings)
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, "Payment settings updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset) |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto p-6">
      <div class="mb-6">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-slate-800">Payment Settings</h1>
            <p class="text-slate-600 mt-1">Configure payout schedules, fees, and payment provider settings</p>
          </div>
        </div>
      </div>

      <div class="max-w-3xl">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="bg-white shadow-sm border border-slate-200 rounded-lg">
            <div class="px-6 py-5">
              <h3 class="text-lg font-semibold text-slate-800 mb-1">Payout Schedule</h3>
              <p class="text-sm text-slate-600 mb-4">Configure when artisans receive their payouts</p>
              <div class="mt-5 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Schedule Type</label>
                  <select
                    name="payout_settings[schedule_type]"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  >
                    <option value="weekly" selected={@settings.schedule_type == "weekly"}>Weekly</option>
                    <option value="monthly" selected={@settings.schedule_type == "monthly"}>Monthly</option>
                  </select>
                  <%= if @changeset.errors[:schedule_type] do %>
                    <p class="mt-2 text-sm text-red-600"><%= elem(@changeset.errors[:schedule_type], 0) %></p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">
                    Schedule Day
                    <span class="text-gray-500 text-xs">(1-7 for weekly, 1-31 for monthly)</span>
                  </label>
                  <input
                    type="number"
                    name="payout_settings[schedule_day]"
                    value={@settings.schedule_day}
                    min="1"
                    max="31"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                  <%= if @changeset.errors[:schedule_day] do %>
                    <p class="mt-2 text-sm text-red-600"><%= elem(@changeset.errors[:schedule_day], 0) %></p>
                  <% end %>
                  <p class="mt-2 text-sm text-gray-500">
                    <%= if @settings.schedule_type == "weekly" do %>
                      1 = Monday, 2 = Tuesday, ..., 7 = Sunday
                    <% else %>
                      Day of the month (1-31)
                    <% end %>
                  </p>
                </div>

                <div>
                  <label class="flex items-center">
                    <input
                      type="checkbox"
                      name="payout_settings[is_active]"
                      checked={@settings.is_active}
                      class="rounded border-gray-300 text-indigo-600 shadow-sm focus:ring-indigo-500"
                    />
                    <span class="ml-2 text-sm text-gray-700">Enable automatic payouts</span>
                  </label>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white shadow-sm border border-slate-200 rounded-lg">
            <div class="px-6 py-5">
              <h3 class="text-lg font-semibold text-slate-800 mb-1">Payout Amounts</h3>
              <p class="text-sm text-slate-600 mb-4">Set minimum payout thresholds and platform fees</p>
              <div class="mt-5 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Minimum Payout Amount (ZMW)</label>
                  <input
                    type="number"
                    name="payout_settings[minimum_payout_amount]"
                    value={@settings.minimum_payout_amount}
                    step="0.01"
                    min="0"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                  <%= if @changeset.errors[:minimum_payout_amount] do %>
                    <p class="mt-2 text-sm text-red-600"><%= elem(@changeset.errors[:minimum_payout_amount], 0) %></p>
                  <% end %>
                  <p class="mt-2 text-sm text-gray-500">
                    Artisans must have at least this amount in earnings to receive a payout.
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Platform Fee (%)</label>
                  <input
                    type="number"
                    name="payout_settings[platform_fee_percentage]"
                    value={@settings.platform_fee_percentage}
                    step="0.01"
                    min="0"
                    max="100"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  />
                  <%= if @changeset.errors[:platform_fee_percentage] do %>
                    <p class="mt-2 text-sm text-red-600"><%= elem(@changeset.errors[:platform_fee_percentage], 0) %></p>
                  <% end %>
                  <p class="mt-2 text-sm text-gray-500">
                    Percentage deducted from artisan earnings as platform fee.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white shadow-sm border border-slate-200 rounded-lg">
            <div class="px-6 py-5">
              <h3 class="text-lg font-semibold text-slate-800 mb-1">pawaPay Configuration</h3>
              <p class="text-sm text-slate-600 mb-4">View API credentials and configuration</p>
              <div class="mt-5 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">API Token</label>
                  <input
                    type="password"
                    value={Application.get_env(:handmade_hub, :pawapay_api_token) || "Not configured"}
                    disabled
                    class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
                  />
                  <p class="mt-2 text-sm text-gray-500">
                    Configure via PAWAPAY_API_TOKEN environment variable.
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Base URL</label>
                  <input
                    type="text"
                    value={Application.get_env(:handmade_hub, :pawapay_base_url, "https://api.sandbox.pawapay.io")}
                    disabled
                    class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
                  />
                  <p class="mt-2 text-sm text-gray-500">
                    Configure via PAWAPAY_BASE_URL environment variable.
                  </p>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Callback URL</label>
                  <input
                    type="text"
                    value={Application.get_env(:handmade_hub, :pawapay_callback_url, "Not configured")}
                    disabled
                    class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm sm:text-sm"
                  />
                  <p class="mt-2 text-sm text-gray-500">
                    Configure this URL in your pawaPay dashboard for all callback types.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end pt-4">
            <button
              type="submit"
              class="inline-flex items-center px-6 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg shadow-md transition-all duration-200 hover:shadow-lg"
            >
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              Save Settings
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
