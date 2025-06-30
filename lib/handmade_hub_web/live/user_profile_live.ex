defmodule HandmadeHubWeb.UserProfileLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Accounts
  alias HandmadeHub.Accounts.User

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    form = to_form(User.profile_changeset(user, %{}))

    {:ok, assign(socket, form: form, uploaded_files: [], page_title: "Edit Profile")}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.profile_changeset(socket.assigns.current_user, user_params)
    {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case handle_upload(socket, user_params) do
      {:ok, updated_params} ->
        case Accounts.update_user_profile(socket.assigns.current_user, updated_params) do
          {:ok, _user} ->
            {:noreply,
             socket
             |> put_flash(:info, "Profile updated successfully.")
             |> push_navigate(to: ~p"/users/settings/profile")} # Update destination
          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  defp handle_upload(_socket, %{"profile_image" => %Phoenix.LiveView.UploadEntry{} = upload} = params) do
    upload_path = Path.join(["priv/static/uploads/profile_images", upload.client_name])
    File.cp(upload.path, upload_path)
    {:ok, Map.put(params, "profile_image", "/uploads/profile_images/#{upload.client_name}")}
  end

  defp handle_upload(_socket, params), do: {:ok, params}
end
