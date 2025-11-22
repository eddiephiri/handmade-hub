defmodule HandmadeHubWeb.Admin.AdminsLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.Admins
  alias HandmadeHub.Admins.Admin
  alias HandmadeHub.Audit

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", admins: Admins.list_admins(), show_modal: false, confirming_action: nil)
     |> assign_form(Admins.change_admin_registration(%Admin{}))}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q, admins: Admins.list_admins(search: q))}
  end

  def handle_event("open_modal", _, socket) do
    {:noreply,
     socket
     |> assign(show_modal: true)
     |> assign_form(Admins.change_admin_registration(%Admin{}))}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  # Prevent modal from closing when clicking inside the content area
  def handle_event("ignore", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> Admins.change_admin_registration(admin_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"admin" => admin_params}, socket) do
    # Only super_admin can create other admins
    if socket.assigns.current_admin.role == "super_admin" do
      case Admins.register_admin(admin_params) do
        {:ok, admin} ->
          _ =
            Audit.log_admin_action(
              admin_id: socket.assigns.current_admin.id,
              target_user_id: nil,
              action: "admin_created",
              metadata: %{admin_id: admin.id, role: admin.role}
            )

          {:noreply,
           socket
           |> put_flash(:info, "Admin created successfully. Account is pending approval.")
           |> assign(show_modal: false, admins: Admins.list_admins())}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "Only super admins can create new admins")}
    end
  end

  def handle_event("confirm_approve", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirming_action: %{action: "approve", id: id})}
  end

  def handle_event("confirm_reject", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirming_action: %{action: "reject", id: id})}
  end

  def handle_event("clear_confirmation", _params, socket) do
    {:noreply, assign(socket, confirming_action: nil)}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    if socket.assigns.current_admin.role == "super_admin" do
      admin = Admins.get_admin!(id)

      case Admins.approve_admin(admin) do
        {:ok, _admin} ->
          _ =
            Audit.log_admin_action(
              admin_id: socket.assigns.current_admin.id,
              target_user_id: nil,
              action: "admin_approved",
              metadata: %{admin_id: admin.id}
            )

          {:noreply,
           socket
           |> put_flash(:info, "Admin approved successfully")
           |> assign(admins: Admins.list_admins(), confirming_action: nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not approve admin") |> assign(confirming_action: nil)}
      end
    else
      {:noreply, put_flash(socket, :error, "Only super admins can approve admins") |> assign(confirming_action: nil)}
    end
  end

  def handle_event("reject", %{"id" => id}, socket) do
    if socket.assigns.current_admin.role == "super_admin" do
      admin = Admins.get_admin!(id)

      case Admins.reject_admin(admin) do
        {:ok, _} ->
          _ =
            Audit.log_admin_action(
              admin_id: socket.assigns.current_admin.id,
              target_user_id: nil,
              action: "admin_rejected",
              metadata: %{admin_id: admin.id}
            )

          {:noreply,
           socket
           |> put_flash(:info, "Admin rejected and removed")
           |> assign(admins: Admins.list_admins(), confirming_action: nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not reject admin") |> assign(confirming_action: nil)}
      end
    else
      {:noreply, put_flash(socket, :error, "Only super admins can reject admins") |> assign(confirming_action: nil)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    admin = Admins.get_admin!(id)

    # Prevent admins from deleting themselves
    if admin.id == socket.assigns.current_admin.id do
      {:noreply, put_flash(socket, :error, "You cannot delete your own account. Please ask another admin to do this.")}
    else
      case Admins.delete_admin(admin) do
        {:ok, _} ->
          _ =
            Audit.log_admin_action(
              admin_id: socket.assigns.current_admin.id,
              target_user_id: nil,
              action: "admin_deleted",
              metadata: %{admin_id: admin.id}
            )

          {:noreply, assign(socket, admins: Admins.list_admins(search: socket.assigns.search))}

        {:error, :cannot_delete_last_super_admin} ->
          {:noreply, put_flash(socket, :error, "Cannot delete the last super admin")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete admin")}
      end
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  # Helper function to determine admin status
  def admin_status(admin) do
    if admin.confirmed_at, do: "approved", else: "pending"
  end

  # Helper function to get status badge class
  def status_badge_class(status) do
    case status do
      "approved" -> "bg-green-100 text-green-800"
      "pending" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
