defmodule HandmadeHubWeb.Admin.BuyersLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.Accounts
  alias HandmadeHub.Audit

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", status: "all", buyers: Accounts.list_buyers())}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    buyers = Accounts.list_buyers(search: q, suspended: suspended_filter(socket.assigns.status))
    {:noreply, assign(socket, search: q, buyers: buyers)}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    buyers = Accounts.list_buyers(search: socket.assigns.search, suspended: suspended_filter(status))
    {:noreply, assign(socket, status: status, buyers: buyers)}
  end

  def handle_event("toggle_suspend", %{"id" => id, "suspend" => suspend}, socket) do
    user = Accounts.get_user!(id)
    suspend? = suspend == "true"
    {:ok, _} = Accounts.update_buyer_suspension(user, suspend?)

    _ = Audit.log_admin_action(
      admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
      target_user_id: user.id,
      action: if(suspend?, do: "buyer_suspended", else: "buyer_unsuspended"),
      metadata: %{}
    )

    buyers = Accounts.list_buyers(search: socket.assigns.search, suspended: suspended_filter(socket.assigns.status))
    {:noreply, assign(socket, buyers: buyers)}
  end

  defp suspended_filter("suspended"), do: true
  defp suspended_filter("active"), do: false
  defp suspended_filter(_), do: nil
end
