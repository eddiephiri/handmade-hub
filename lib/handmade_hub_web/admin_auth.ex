defmodule HandmadeHubWeb.AdminAuth do
  use HandmadeHubWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias HandmadeHub.Admins

  @remember_me_cookie "_handmade_hub_web_admin_remember_me"
  defp remember_me_max_age, do: Application.get_env(:handmade_hub, :remember_me_max_age, 60 * 60 * 24 * 60)
  defp remember_me_options, do: [sign: true, max_age: remember_me_max_age(), same_site: "Lax"]

  def log_in_admin(conn, admin, params \\ %{}) do
    token = HandmadeHub.Admins.generate_admin_session_token(admin)

    conn
    |> renew_session()
    |> put_session(:admin_token, token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: admin_signed_in_path(conn))
  end

  def log_out_admin(conn) do
    admin_token = get_session(conn, :admin_token)
    admin_token && HandmadeHub.Admins.delete_admin_session_token(admin_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/admin/log_in")
  end

  def fetch_current_admin(conn, _opts) do
    {token, conn} = ensure_admin_token(conn)
    admin = token && HandmadeHub.Admins.get_admin_by_session_token(token)
    assign(conn, :current_admin, admin)
  end

  def redirect_if_admin_is_authenticated(conn, _opts) do
    if conn.assigns[:current_admin] do
      conn |> redirect(to: admin_signed_in_path(conn)) |> halt()
    else
      conn
    end
  end

  def require_authenticated_admin(conn, _opts) do
    if conn.assigns[:current_admin] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in as admin to access this page.")
      |> redirect(to: ~p"/admin/log_in")
      |> halt()
    end
  end

  defp ensure_admin_token(conn) do
    if token = get_session(conn, :admin_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])
      cookie_token = conn.cookies[@remember_me_cookie]
      verified_token =
        case cookie_token do
          nil -> nil
          _ ->
            case Phoenix.Token.verify(HandmadeHubWeb.Endpoint, "admin_remember", cookie_token, max_age: remember_me_max_age()) do
              {:ok, token} -> token
              _ -> nil
            end
        end
      {verified_token, if(verified_token, do: put_session(conn, :admin_token, verified_token), else: conn)}
    end
  end

  # session tokens handled by Admins context

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, Phoenix.Token.sign(HandmadeHubWeb.Endpoint, "admin_remember", token), remember_me_options())
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params), do: conn

  defp admin_signed_in_path(_conn), do: "/admin/dashboard"

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  # LiveView on_mount helpers for admins

  def on_mount(:mount_current_admin, _params, session, socket) do
    {:cont, mount_current_admin(socket, session)}
  end

  def on_mount(:ensure_authenticated_admin, _params, session, socket) do
    socket = mount_current_admin(socket, session)

    if socket.assigns.current_admin do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in as admin to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/admin/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_admin_is_authenticated, _params, session, socket) do
    socket = mount_current_admin(socket, session)

    if socket.assigns.current_admin do
      {:halt, Phoenix.LiveView.redirect(socket, to: admin_signed_in_path(%{}))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_admin(socket, session) do
    Phoenix.Component.assign_new(socket, :current_admin, fn ->
      if admin_token = session["admin_token"] do
        Admins.get_admin_by_session_token(admin_token)
      end
    end)
  end
end
