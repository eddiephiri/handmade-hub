defmodule HandmadeHubWeb.AdminSessionController do
  use HandmadeHubWeb, :controller

  alias HandmadeHub.Admins
  alias HandmadeHubWeb.AdminAuth

  def new(conn, _params) do
    form = Phoenix.Component.to_form(%{"email" => ""}, as: "admin")
    conn
    |> put_layout(html: {HandmadeHubWeb.Layouts, :auth})
    |> render(:new, form: form)
  end

  def create(conn, %{"admin" => %{"email" => email, "password" => password} = params}) do
    case Admins.get_admin_by_email_and_password(email, password) do
      %_{} = admin ->
        conn
        |> put_flash(:info, "Welcome back, admin!")
        |> AdminAuth.log_in_admin(admin, params)
      _ ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/admin/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AdminAuth.log_out_admin()
  end
end
