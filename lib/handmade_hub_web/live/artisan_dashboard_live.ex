defmodule HandmadeHubWeb.ArtisanDashboardLive do
  use HandmadeHubWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    if user.role != "artisan" do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    else
      form = HandmadeHub.Accounts.User.profile_changeset(user, %{}) |> to_form()
      password_form = HandmadeHub.Accounts.change_user_password(user) |> to_form()
      {:ok, assign(socket, page: :dashboard, products: [], product_streams: %{}, show_modal: false, modal_action: nil, modal_product: nil, show_delete_modal: false, delete_product_id: nil, profile_form: form, password_form: password_form, current_password: nil, trigger_submit: false, show_password_form: false)}
    end
  end

  @impl true
  def handle_event("show_products", _params, socket) do
    products = HandmadeHub.Catalog.list_user_products(socket.assigns.current_user.id)
    product_streams = %{products: Enum.with_index(products) |> Enum.into(%{}, fn {p, i} -> {i, p} end)}
    {:noreply, assign(socket, page: :products, products: products, product_streams: product_streams)}
  end

  def handle_event("show_dashboard", _params, socket) do
    {:noreply, assign(socket, page: :dashboard)}
  end

  def handle_event("new_product", _params, socket) do
    {:noreply, assign(socket, show_modal: true, modal_action: :new, modal_product: %HandmadeHub.Catalog.Product{})}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, modal_action: nil, modal_product: nil)}
  end

  def handle_event("edit_product", %{"id" => id}, socket) do
    product = HandmadeHub.Catalog.get_product!(id)
    {:noreply, assign(socket, show_modal: true, modal_action: :edit, modal_product: product)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_delete_modal: true, delete_product_id: id)}
  end

  def handle_event("confirm_delete", _params, socket) do
    product = HandmadeHub.Catalog.get_product!(socket.assigns.delete_product_id)
    {:ok, _} = HandmadeHub.Catalog.delete_product(product)
    products = HandmadeHub.Catalog.list_user_products(socket.assigns.current_user.id)
    product_streams = %{products: Enum.with_index(products) |> Enum.into(%{}, fn {p, i} -> {i, p} end)}
    {:noreply, socket
      |> put_flash(:info, "Product deleted successfully.")
      |> assign(show_delete_modal: false, delete_product_id: nil, products: products, product_streams: product_streams)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false, delete_product_id: nil)}
  end

  def handle_event("show_profile", _params, socket) do
    user = socket.assigns.current_user
    form = HandmadeHub.Accounts.User.profile_changeset(user, %{}) |> to_form()
    password_form = HandmadeHub.Accounts.change_user_password(user) |> to_form()
    {:noreply, assign(socket, page: :profile, profile_form: form, password_form: password_form, current_password: nil, trigger_submit: false, show_password_form: false)}
  end

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    changeset = HandmadeHub.Accounts.profile_changeset(socket.assigns.current_user, user_params)
    {:noreply, assign(socket, profile_form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save_profile", %{"user" => user_params}, socket) do
    case handle_profile_upload(socket, user_params) do
      {:ok, updated_params} ->
        case HandmadeHub.Accounts.update_user_profile(socket.assigns.current_user, updated_params) do
          {:ok, _user} ->
            {:noreply, put_flash(socket, :info, "Profile updated successfully.")}
          {:error, changeset} ->
            {:noreply, assign(socket, profile_form: to_form(changeset))}
        end
    end
  end

  def handle_event("validate_password", %{"current_password" => password, "user" => user_params}, socket) do
    password_form =
      socket.assigns.current_user
      |> HandmadeHub.Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()
    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", %{"current_password" => password, "user" => user_params}, socket) do
    user = socket.assigns.current_user
    case HandmadeHub.Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form = HandmadeHub.Accounts.change_user_password(user) |> to_form()
        {:noreply, socket
          |> put_flash(:info, "Password updated successfully.")
          |> assign(trigger_submit: true, password_form: password_form)}
      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("toggle_password_form", _params, socket) do
    {:noreply, assign(socket, show_password_form: !socket.assigns.show_password_form)}
  end

  defp handle_profile_upload(_socket, %{"profile_image" => %Phoenix.LiveView.UploadEntry{} = upload} = params) do
    upload_path = Path.join(["priv/static/uploads/profile_images", upload.client_name])
    File.cp(upload.path, upload_path)
    {:ok, Map.put(params, "profile_image", "/uploads/profile_images/#{upload.client_name}")}
  end
  defp handle_profile_upload(_socket, params), do: {:ok, params}

  @impl true
  def handle_info({HandmadeHubWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    # Refresh products after save
    products = HandmadeHub.Catalog.list_user_products(socket.assigns.current_user.id)
    product_streams = %{products: Enum.with_index(products) |> Enum.into(%{}, fn {p, i} -> {i, p} end)}
    action = if socket.assigns.modal_action == :edit, do: "updated", else: "created"
    {:noreply, socket
      |> put_flash(:info, "Product #{action} successfully.")
      |> assign(show_modal: false, modal_action: nil, modal_product: nil, products: products, product_streams: product_streams, page: :products)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-50">
      <!-- Sidebar -->
      <aside class="w-64 bg-white border-r border-gray-200 flex-shrink-0 hidden md:block">
        <div class="h-full flex flex-col p-6">
          <div class="mb-8">
            <h2 class="text-2xl font-bold text-blue-700">Artisan Hub</h2>
            <p class="text-sm text-gray-500 mt-1">Welcome, <%= @current_user.name || @current_user.email %></p>
          </div>
          <nav class="flex-1 space-y-2">
            <button phx-click="show_dashboard" class="block w-full text-left px-4 py-2 rounded-lg hover:bg-blue-50 text-gray-700 font-medium">Dashboard Home</button>
            <button phx-click="show_profile" class="block w-full text-left px-4 py-2 rounded-lg hover:bg-blue-50 text-gray-700 font-medium">Profile</button>
            <button phx-click="show_products" class="block w-full text-left px-4 py-2 rounded-lg hover:bg-blue-50 text-gray-700 font-medium">My Products</button>
            <.link navigate="#" class="block px-4 py-2 rounded-lg hover:bg-blue-50 text-gray-700 font-medium">Orders</.link>
            <.link navigate="#" class="block px-4 py-2 rounded-lg hover:bg-blue-50 text-gray-700 font-medium">Messages</.link>
            <.link navigate="#" class="block px-4 py-2 rounded-lg hover:bg-blue-50 text-gray-700 font-medium">Reviews</.link>
            <.link href="/users/log_out" method="delete" class="block px-4 py-2 rounded-lg hover:bg-red-50 text-red-600 font-medium mt-8">Logout</.link>
          </nav>
        </div>
      </aside>
      <!-- Mobile sidebar toggle (optional) -->
      <div class="md:hidden fixed top-0 left-0 z-40">
        <!-- Add a mobile sidebar toggle button here if needed -->
      </div>
      <!-- Main Content -->
      <main class="flex-1 p-6">
        <.flash_group flash={@flash} />
        <%= if @page == :dashboard do %>
          <h1 class="text-2xl font-bold mb-4">Artisan Dashboard</h1>
          <div class="bg-white rounded-lg shadow p-6 min-h-[300px]">
            <p class="text-gray-600">Welcome to your artisan dashboard. Use the navigation panel to manage your profile, products, orders, and more.</p>
          </div>
        <% end %>
        <%= if @page == :products do %>
          <h1 class="text-2xl font-bold mb-4">My Products</h1>
          <div class="mb-4">
            <.button phx-click="new_product">New Product</.button>
          </div>
          <div id="products" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-6">
            <div :for={{_id, product} <- @product_streams.products} class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="aspect-w-16 aspect-h-9">
                <%= if product.image do %>
                  <img src={product.image} alt={product.name} class="w-full h-48 object-cover">
                <% else %>
                  <div class="w-full h-48 bg-gray-200 flex items-center justify-center">
                    <span class="text-gray-500">No image</span>
                  </div>
                <% end %>
              </div>
              <div class="p-4">
                <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= product.name %></h3>
                <p class="text-gray-600 text-sm mb-3 line-clamp-2"><%= product.description %></p>
                <div class="flex justify-between items-center mb-4">
                  <span class="text-xl font-bold text-green-600">K<%= product.price %></span>
                  <span class="text-sm text-gray-500">Qty: <%= product.quantity %></span>
                </div>
                <div class="flex space-x-2">
                  <.link navigate={"/products/#{product.id}"} class="flex-1">
                    <.button class="w-full">View</.button>
                  </.link>
                  <.button class="w-full flex-1" phx-click="edit_product" phx-value-id={product.id}>Edit</.button>
                  <.button
                    phx-click="delete"
                    phx-value-id={product.id}
                    class="px-3 py-2 bg-red-600 text-white rounded hover:bg-red-700"
                  >
                    Delete
                  </.button>
                </div>
              </div>
            </div>
          </div>
          <%= if map_size(@product_streams.products) == 0 do %>
            <div class="text-center py-12">
              <div class="mx-auto h-24 w-24 text-gray-400">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>
                </svg>
              </div>
              <h3 class="mt-4 text-lg font-medium text-gray-900">No products yet</h3>
              <p class="mt-2 text-gray-500">Get started by creating your first product.</p>
              <div class="mt-6">
                <.button phx-click="new_product">New Product</.button>
              </div>
            </div>
          <% end %>
          <.modal :if={@show_modal} id="product-modal" show on_cancel={JS.push("close_modal")}>
            <.live_component
              module={HandmadeHubWeb.ProductLive.FormComponent}
              id={(@modal_product && @modal_product.id) || :new}
              title={@modal_action == :edit && @modal_product && @modal_product.name || "New Product"}
              action={@modal_action}
              product={@modal_product}
              current_user={@current_user}
            />
          </.modal>
          <.modal :if={@show_delete_modal} id="delete-modal" show on_cancel={JS.push("cancel_delete")}>
            <div class="p-6">
              <h2 class="text-lg font-bold mb-4">Confirm Delete</h2>
              <p>Are you sure you want to delete this product? This action cannot be undone.</p>
              <div class="mt-6 flex justify-end gap-2">
                <.button phx-click="cancel_delete" class="bg-gray-200 text-gray-800">Cancel</.button>
                <.button phx-click="confirm_delete" class="bg-red-600 text-white">Delete</.button>
              </div>
            </div>
          </.modal>
        <% end %>
        <%= if @page == :profile do %>
          <div class="mx-auto max-w-lg mt-10">
            <.header class="mb-6 text-center">
              Edit Your Profile
            </.header>
            <%= if @current_user.profile_image do %>
              <div class="flex justify-center mb-6">
                <img src={@current_user.profile_image} alt="Profile Image" class="w-24 h-24 rounded-full object-cover border-2 border-blue-500" />
              </div>
            <% end %>
            <.simple_form
              for={@profile_form}
              id="profile_form"
              phx-submit="save_profile"
              phx-change="validate_profile"
            >
              <.input field={@profile_form[:name]} type="text" label="Name" />
              <.input field={@profile_form[:bio]} type="textarea" label="Bio" />
              <.input
                field={@profile_form[:profile_image]}
                type="file"
                label="Profile Image"
                accept="image/*"
              />
              <:actions>
                <.button class="w-full">Save Changes</.button>
              </:actions>
            </.simple_form>
            <div class="mt-12 text-center">
              <.button phx-click="toggle_password_form" class="mb-4">
                <%= if @show_password_form, do: "Hide Password Change", else: "Change Password" %>
              </.button>
            </div>
            <%= if @show_password_form do %>
              <div class="mt-4">
                <.header class="mb-4 text-center">Change Password</.header>
                <.simple_form
                  for={@password_form}
                  id="password_form"
                  phx-change="validate_password"
                  phx-submit="update_password"
                >
                  <.input field={@password_form[:password]} type="password" label="New password" required />
                  <.input field={@password_form[:password_confirmation]} type="password" label="Confirm new password" />
                  <.input field={@password_form[:current_password]} name="current_password" type="password" label="Current password" value={@current_password} required />
                  <:actions>
                    <.button phx-disable-with="Changing..." class="w-full">Change Password</.button>
                  </:actions>
                </.simple_form>
              </div>
            <% end %>
          </div>
        <% end %>
      </main>
    </div>
    """
  end
end
