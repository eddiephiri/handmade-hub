defmodule HandmadeHubWeb.PageController do
  use HandmadeHubWeb, :controller

  def home(conn, _params) do
    Phoenix.Controller.redirect(conn, to: "/browse")
  end
end
