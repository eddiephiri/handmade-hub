defmodule HandmadeHubWeb.AdminDashboardController do
  use HandmadeHubWeb, :controller
  import HandmadeHubWeb.AdminAuth, only: [require_authenticated_admin: 2]
  plug :require_authenticated_admin

  def index(conn, _params) do
    render(conn, :index)
  end
end
