defmodule HandmadeHubWeb.Admin.ArtisansLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.AdminAuth, only: [require_authenticated_admin: 2]
  alias HandmadeHub.Accounts
  alias HandmadeHub.Audit

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_user, nil)
     |> assign(search: "", status: "", artisans: Accounts.list_artisans())}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q, artisans: Accounts.list_artisans(search: q, artisan_status: blank_to_nil(socket.assigns.status)))}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, status: status, artisans: Accounts.list_artisans(search: socket.assigns.search, artisan_status: blank_to_nil(status)))}
  end

  def handle_event("set_status", %{"id" => id, "status" => status}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.update_artisan_status(user, status)

    _ = Audit.log_admin_action(
      admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
      target_user_id: user.id,
      action: "artisan_status_changed",
      metadata: %{new_status: status}
    )

    {:noreply, assign(socket, artisans: Accounts.list_artisans(search: socket.assigns.search, artisan_status: blank_to_nil(socket.assigns.status)))}
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v
end
