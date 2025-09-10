defmodule HandmadeHubWeb.MaintenancePlug do
  import Plug.Conn
  alias HandmadeHub.Settings

  def init(opts), do: opts

  def call(conn, _opts) do
    if Settings.get("maintenance_mode", false) do
      conn
      |> Phoenix.Controller.put_view(HandmadeHubWeb.PageHTML)
      |> Phoenix.Controller.render(:maintenance)
      |> halt()
    else
      conn
    end
  end
end
