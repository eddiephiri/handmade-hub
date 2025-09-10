defmodule HandmadeHubWeb.Admin.AdminShowLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.Admins
  alias HandmadeHub.Audit

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    admin = Admins.get_admin!(id)
    {:ok, assign(socket, admin: admin, form: to_form(%{"email" => admin.email, "username" => admin.username, "role" => admin.role}))}
  end

  @impl true
  def handle_event("save", %{"admin" => attrs}, socket) do
    case Admins.update_admin(socket.assigns.admin, attrs) do
      {:ok, admin} ->
        _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: nil, action: "admin_updated", metadata: %{admin_id: admin.id, fields: Map.keys(attrs)})
        {:noreply, assign(socket, admin: admin, form: to_form(attrs))}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update admin")}
    end
  end
end
