defmodule HandmadeHubWeb.PageController do
  use HandmadeHubWeb, :controller

  def home(conn, _params) do
    Phoenix.LiveView.Controller.live_render(conn, HandmadeHubWeb.BrowseLive.Index, session: %{})
  end
end
