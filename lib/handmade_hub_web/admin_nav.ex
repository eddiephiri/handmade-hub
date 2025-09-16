defmodule HandmadeHubWeb.AdminNav do
  @moduledoc """
  Assigns the current admin path to the LiveView socket so the admin sidebar
  can render an active state for the current section.
  """

  @doc """
  Attach a handle_params hook that captures the current URL and stores its path
  in `:current_admin_path`.
  """
  def on_mount(:nav, _params, _session, socket) do
    socket =
      Phoenix.LiveView.attach_hook(
        socket,
        :admin_nav_current_path,
        :handle_params,
        fn _params, url, socket ->
          path = url |> URI.parse() |> Map.get(:path)
          {:cont, Phoenix.Component.assign(socket, :current_admin_path, path)}
        end
      )

    {:cont, socket}
  end
end
