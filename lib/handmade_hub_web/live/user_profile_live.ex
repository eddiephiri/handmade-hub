defmodule HandmadeHubWeb.UserProfileLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Accounts
  alias HandmadeHub.Accounts.User

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    form = to_form(User.profile_changeset(user, %{}))

    socket =
      socket
      |> allow_upload(:profile_image,
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000
      )

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

	def handle_event("back_to_dashboard", _params, socket) do
		{:noreply,
		 socket
		 |> put_flash(:info, "Your artisan account requires approval before accessing the dashboard. Please complete your profile and wait for approval.")}
	end

  defp handle_upload(socket, params) do
    uploads_dir = "priv/static/uploads/profile_images"
    File.mkdir_p!(uploads_dir)

    uploaded_urls = consume_uploaded_entries(socket, :profile_image, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      filename = "#{Ecto.UUID.generate()}#{ext}"
      dest_path = Path.join(uploads_dir, filename)
      File.cp!(path, dest_path)
      {:ok, "/uploads/profile_images/#{filename}"}
    end)

    case uploaded_urls do
      [url | _] -> {:ok, Map.put(params, "profile_image", url)}
      _ -> {:ok, params}
    end
  end
end
