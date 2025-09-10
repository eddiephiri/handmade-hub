defmodule HandmadeHubWeb.Admin.AnalyticsLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Orders, Accounts, Catalog}

  @impl true
  def mount(_params, _session, socket) do
    series = Orders.orders_monthly_series(12)
    {:ok,
     assign(socket,
       series: series,
       total_users: Accounts.count_users(),
       total_artisans: Accounts.count_artisans(),
       total_buyers: Accounts.count_buyers(),
       total_products: Catalog.count_products()
     )}
  end
end
