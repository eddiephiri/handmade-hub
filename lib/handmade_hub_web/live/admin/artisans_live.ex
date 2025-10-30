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
     |> assign(search: "", status: "", artisans: Accounts.list_artisans(), confirming_action: nil)}
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

  def handle_event("confirm_status_change", %{"id" => id, "status" => status}, socket) do
    socket = assign(socket, :confirming_action, %{id: id, status: status})
    {:noreply, socket}
  end

  def handle_event("clear_confirm_status_change", _, socket) do
    {:noreply, assign(socket, :confirming_action, nil)}
  end

  def handle_event("execute_status_change", %{"id" => id, "status" => status}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.update_artisan_status(user, status)

    _ = Audit.log_admin_action(
      admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
      target_user_id: user.id,
      action: "artisan_status_changed",
      metadata: %{new_status: status}
    )

    {:noreply,
     socket
     |> assign(artisans: Accounts.list_artisans(search: socket.assigns.search, artisan_status: blank_to_nil(socket.assigns.status)))
     |> assign(confirming_action: nil)}
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  # Returns a user-friendly action phrase based on the status for the confirmation modal
  defp confirmation_action_message("approved"), do: "approve"
  defp confirmation_action_message("rejected"), do: "reject"
  defp confirmation_action_message("suspended"), do: "suspend"
  defp confirmation_action_message("pending"), do: "reset this artisan's status to pending"
  defp confirmation_action_message(val), do: val
end
