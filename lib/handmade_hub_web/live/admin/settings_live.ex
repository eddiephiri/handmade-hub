defmodule HandmadeHubWeb.Admin.SettingsLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.Settings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:maintenance_mode, Settings.get("maintenance_mode", false))
     |> assign(:commission_rate, Settings.get("commission_rate", 10))
     |> assign(:payment_gateway, Settings.get("payment_gateway", "stripe"))}
  end

  @impl true
  def handle_event("save", %{"settings" => params}, socket) do
    mm = params["maintenance_mode"] == "true"
    gateway = params["payment_gateway"] || "stripe"
    rate = params["commission_rate"] |> case do
      nil -> 10
      s -> String.to_integer(s)
    end

    _ = Settings.put("maintenance_mode", mm, "boolean")
    _ = Settings.put("payment_gateway", gateway, "string")
    _ = Settings.put("commission_rate", rate, "integer")

    {:noreply,
     socket
     |> put_flash(:info, "Settings saved")
     |> assign(maintenance_mode: mm, commission_rate: rate, payment_gateway: gateway)}
  end
end
