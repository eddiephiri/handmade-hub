defmodule HandmadeHubWeb.Admin.ArtisanShowLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Accounts, Catalog, Orders, Audit}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user!(id)
    {:ok, assign(socket, user: user, form: Accounts.update_user_profile(user, %{}) |> case do
      {:ok, u} -> to_form(%{"name" => u.name, "bio" => u.bio})
      _ -> to_form(%{"name" => user.name, "bio" => user.bio})
    end,
      products: Catalog.list_user_products(user.id),
      orders: Orders.list_user_orders(user.id),
      activity_logs: Audit.list_user_activity_logs(user.id, limit: 20))}
  end

  @impl true
  def handle_event("save_profile", %{"user" => attrs}, socket) do
    case Accounts.update_user_profile(socket.assigns.user, attrs) do
      {:ok, user} ->
        _ = Audit.log_admin_action(
          admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id),
          target_user_id: user.id,
          action: "artisan_profile_updated",
          metadata: %{updated: Map.keys(attrs)}
        )

        {:noreply, socket |> put_flash(:info, "Profile updated") |> assign(user: user, form: to_form(attrs))}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update profile")}
    end
  end
end
