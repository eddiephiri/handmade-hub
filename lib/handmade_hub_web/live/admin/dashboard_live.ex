defmodule HandmadeHubWeb.Admin.DashboardLive do
  use HandmadeHubWeb, :live_view
  import Ecto.Query

  alias HandmadeHub.{Accounts, Catalog, Orders, Reviews}
  alias HandmadeHub.Accounts.User
  alias HandmadeHub.Catalog.Product
  alias HandmadeHub.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Admin Dashboard", page: :dashboard, sidebar_collapsed: false)
     |> assign(:show_admin_sidebar, false)
     |> load_data()}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, sidebar_collapsed: !socket.assigns.sidebar_collapsed)}
  end

  defp load_data(socket) do
    totals = %{
      users: Accounts.count_users(),
      artisans: Accounts.count_artisans(),
      buyers: Accounts.count_buyers(),
      products: Catalog.count_products()
    }

    order_stats = Orders.get_order_stats()
    monthly = Orders.orders_monthly_series(6)

    pending_artisans = Repo.aggregate(from(u in User, where: u.role == "artisan" and u.artisan_status == "pending"), :count)
    pending_products = Repo.aggregate(from(p in Product, where: is_nil(p.removed_at) and p.approval_status == "pending"), :count)
    flagged_reviews = Repo.aggregate(from(r in HandmadeHub.Reviews.Review, where: r.flagged == true), :count)

    recent_orders = Orders.list_orders_admin(%{}) |> Enum.take(6)
    recent_signups = Repo.all(from u in User, order_by: [desc: u.inserted_at], limit: 6)

    socket
    |> assign(
      totals: totals,
      order_stats: order_stats,
      monthly: monthly,
      pending_artisans: pending_artisans,
      pending_products: pending_products,
      flagged_reviews: flagged_reviews,
      recent_orders: recent_orders,
      recent_signups: recent_signups
    )
  end
end
