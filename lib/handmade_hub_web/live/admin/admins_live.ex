defmodule HandmadeHubWeb.Admin.AdminsLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.Admins
  alias HandmadeHub.Audit

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, search: "", admins: Admins.list_admins())}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q, admins: Admins.list_admins(search: q))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    admin = Admins.get_admin!(id)
    case Admins.delete_admin(admin) do
      {:ok, _} ->
        _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: nil, action: "admin_deleted", metadata: %{admin_id: admin.id})
        {:noreply, assign(socket, admins: Admins.list_admins(search: socket.assigns.search))}
      {:error, :cannot_delete_last_super_admin} ->
        {:noreply, put_flash(socket, :error, "Cannot delete the last super admin")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete admin")}
    end
  end
end
