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
      {:ok, assign(socket,
        page: :dashboard,
        products: [],
        product_streams: %{},
        show_modal: false,
        modal_action: nil,
        modal_product: nil,
        show_delete_modal: false,
        delete_product_id: nil,
        profile_form: form,
        password_form: password_form,
        current_password: nil,
        trigger_submit: false,
        show_password_form: false,
        show_view_modal: false,
        view_product: nil,
        sidebar_collapsed: false
      )}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, sidebar_collapsed: !socket.assigns.sidebar_collapsed)}
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

  def handle_event("view_product", %{"id" => id}, socket) do
    product = HandmadeHub.Catalog.get_product!(id)
    {:noreply, assign(socket, show_view_modal: true, view_product: product)}
  end

  def handle_event("close_view_modal", _params, socket) do
    {:noreply, assign(socket, show_view_modal: false, view_product: nil)}
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
    <div class="flex min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      <!-- Enhanced Modern Sidebar -->
      <aside class={[
        "bg-white/95 backdrop-blur-sm border-r border-slate-200/60 flex-shrink-0 transition-all duration-300 ease-in-out shadow-lg",
        "hidden md:block",
        @sidebar_collapsed && "w-20" || "w-72"
      ]}>
        <div class="h-full flex flex-col">
          <!-- Logo/Brand Section -->
          <div class="p-6 border-b border-slate-100/80">
            <div class="flex items-center justify-between">
              <div class={["flex items-center", @sidebar_collapsed && "justify-center"]}>
                <div class="w-10 h-10 bg-gradient-to-br from-blue-600 to-purple-600 rounded-xl flex items-center justify-center shadow-lg">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                </div>
                <div class={["ml-3", @sidebar_collapsed && "hidden"]}>
                  <h2 class="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                    Artisan Hub
                  </h2>
                  <p class="text-xs text-slate-500 mt-0.5">Creative Dashboard</p>
                </div>
              </div>
              <button
                phx-click="toggle_sidebar"
                class="p-2 rounded-lg hover:bg-slate-100 transition-colors duration-200 text-slate-400 hover:text-slate-600"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
              </button>
            </div>
          </div>

          <!-- User Profile Section -->
          <div class={["p-6 border-b border-slate-100/80", @sidebar_collapsed && "px-4"]}>
            <div class={["flex items-center", @sidebar_collapsed && "justify-center"]}>
              <div class="relative">
                <%= if @current_user.profile_image do %>
                  <img src={@current_user.profile_image} alt="Profile" class="w-12 h-12 rounded-full object-cover ring-2 ring-blue-100" />
                <% else %>
                  <div class="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-white font-semibold shadow-lg">
                    <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
                  </div>
                <% end %>
                <div class="absolute -bottom-1 -right-1 w-4 h-4 bg-green-400 rounded-full border-2 border-white"></div>
              </div>
              <div class={["ml-3 flex-1", @sidebar_collapsed && "hidden"]}>
                <p class="text-sm font-semibold text-slate-700 truncate">
                  <%= @current_user.name || @current_user.email %>
                </p>
                <p class="text-xs text-slate-500">Creative Artisan</p>
              </div>
            </div>
          </div>

          <!-- Navigation -->
          <nav class="flex-1 p-4">
            <div class="space-y-2">
              <!-- Dashboard -->
              <button
                phx-click="show_dashboard"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :dashboard && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5a2 2 0 012-2h4a2 2 0 012 2v6a2 2 0 01-2 2H10a2 2 0 01-2-2V5z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Dashboard</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :dashboard && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Products -->
              <button
                phx-click="show_products"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :products && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>My Products</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :products && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Profile -->
              <button
                phx-click="show_profile"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :profile && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Profile</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :profile && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Orders -->
              <.link
                navigate="#"
                class="w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Orders</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @sidebar_collapsed && "hidden"]}></div>
              </.link>

              <!-- Messages -->
              <.link
                navigate="#"
                class="w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Messages</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @sidebar_collapsed && "hidden"]}></div>
              </.link>

              <!-- Reviews -->
              <.link
                navigate="#"
                class="w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Reviews</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @sidebar_collapsed && "hidden"]}></div>
              </.link>
            </div>
          </nav>

          <!-- Logout Section -->
          <div class="p-4 border-t border-slate-100/80">
            <.link
              href="/users/log_out"
              method="delete"
              class="w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group text-red-600 hover:bg-red-50"
            >
              <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Logout</span>
            </.link>
          </div>
        </div>
      </aside>

      <!-- Mobile Sidebar Overlay -->
      <div class="md:hidden">
        <!-- Mobile menu button -->
        <button
          phx-click="toggle_sidebar"
          class="fixed top-4 left-4 z-50 p-2 rounded-lg bg-white shadow-lg border border-slate-200"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>

      <!-- Main Content -->
      <main class="flex-1 overflow-hidden">
        <div class="p-6 h-full overflow-y-auto">
          <.flash_group flash={@flash} />

          <%= if @page == :dashboard do %>
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-slate-800 mb-2">Welcome back!</h1>
              <p class="text-slate-600">Here's what's happening with your artisan business today.</p>
            </div>

            <!-- Dashboard Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
              <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
                <div class="flex items-center justify-between mb-4">
                  <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                    </svg>
                  </div>
                  <span class="text-2xl font-bold text-slate-800">12</span>
                </div>
                <h3 class="text-sm font-semibold text-slate-600">Active Products</h3>
              </div>

              <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
                <div class="flex items-center justify-between mb-4">
                  <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                  <span class="text-2xl font-bold text-slate-800">8</span>
                </div>
                <h3 class="text-sm font-semibold text-slate-600">New Orders</h3>
              </div>

              <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
                <div class="flex items-center justify-between mb-4">
                  <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                    </svg>
                  </div>
                  <span class="text-2xl font-bold text-slate-800">K2,340</span>
                </div>
                <h3 class="text-sm font-semibold text-slate-600">Total Revenue</h3>
              </div>

              <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
                <div class="flex items-center justify-between mb-4">
                  <div class="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                    </svg>
                  </div>
                  <span class="text-2xl font-bold text-slate-800">4.8</span>
                </div>
                <h3 class="text-sm font-semibold text-slate-600">Avg. Rating</h3>
              </div>
            </div>

            <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-8">
              <h2 class="text-xl font-semibold text-slate-800 mb-4">Getting Started</h2>
              <p class="text-slate-600 mb-6">Welcome to your artisan dashboard! Here you can manage your creative business with ease.</p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="p-4 bg-blue-50 rounded-xl">
                  <h3 class="font-semibold text-blue-900 mb-2">Add Your First Product</h3>
                  <p class="text-blue-700 text-sm mb-4">Showcase your handmade creations to the world.</p>
                  <button phx-click="show_products" class="text-blue-600 hover:text-blue-700 font-medium text-sm">
                    Get Started →
                  </button>
                </div>

                <div class="p-4 bg-green-50 rounded-xl">
                  <h3 class="font-semibold text-green-900 mb-2">Complete Your Profile</h3>
                  <p class="text-green-700 text-sm mb-4">Tell your story and connect with customers.</p>
                  <button phx-click="show_profile" class="text-green-600 hover:text-green-700 font-medium text-sm">
                    Update Profile →
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <%= if @page == :products do %>
            <div class="mb-8">
              <div class="flex items-center justify-between">
                <div>
                  <h1 class="text-3xl font-bold text-slate-800 mb-2">My Products</h1>
                  <p class="text-slate-600">Manage your handmade creations and inventory.</p>
                </div>
                <.button phx-click="new_product" class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-6 py-3 rounded-xl shadow-lg transition-all duration-200 transform hover:scale-105">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  New Product
                </.button>
              </div>
            </div>

            <div id="products" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              <div :for={{_id, product} <- @product_streams.products} class="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden group hover:shadow-lg transition-all duration-300 hover:-translate-y-1">
                <div class="aspect-square relative overflow-hidden">
                  <%= if product.image do %>
                    <img src={product.image} alt={product.name} class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300">
                  <% else %>
                    <div class="w-full h-full bg-gradient-to-br from-slate-100 to-slate-200 flex items-center justify-center">
                      <svg class="w-12 h-12 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </div>
                  <% end %>
                  <div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors duration-300"></div>
                </div>

                <div class="p-5">
                  <h3 class="text-lg font-semibold text-slate-900 mb-2 line-clamp-1"><%= product.name %></h3>
                  <p class="text-slate-600 text-sm mb-4 line-clamp-2 leading-relaxed"><%= product.description %></p>

                  <div class="flex items-center justify-between mb-4">
                    <span class="text-2xl font-bold text-green-600">K<%= product.price %></span>
                    <div class="flex items-center text-sm text-slate-500">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                      </svg>
                      <%= product.quantity %> in stock
                    </div>
                  </div>

                  <div class="flex gap-2">
                    <.button phx-click="view_product" phx-value-id={product.id} class="flex-1 bg-blue-50 hover:bg-blue-100 text-blue-700 border-0 py-2 px-3 rounded-lg text-sm font-medium transition-colors">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                      View
                    </.button>
                    <.button phx-click="edit_product" phx-value-id={product.id} class="flex-1 bg-orange-50 hover:bg-orange-100 text-orange-700 border-0 py-2 px-3 rounded-lg text-sm font-medium transition-colors">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536M9 13h3l8-8a2.828 2.828 0 10-4-4l-8 8v3z" />
                      </svg>
                      Edit
                    </.button>
                    <.button phx-click="delete" phx-value-id={product.id} class="flex-1 bg-red-50 hover:bg-red-100 text-red-700 border-0 py-2 px-3 rounded-lg text-sm font-medium transition-colors">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                      Delete
                    </.button>
                  </div>
                </div>
              </div>
            </div>

            <%= if map_size(@product_streams.products) == 0 do %>
              <div class="text-center py-16">
                <div class="w-24 h-24 mx-auto mb-6 bg-gradient-to-br from-blue-100 to-purple-100 rounded-2xl flex items-center justify-center">
                  <svg class="w-12 h-12 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>
                  </svg>
                </div>
                <h3 class="text-xl font-semibold text-slate-800 mb-2">No products yet</h3>
                <p class="text-slate-600 mb-6 max-w-md mx-auto">Start showcasing your handmade creations! Add your first product to begin your artisan journey.</p>
                <.button phx-click="new_product" class="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-8 py-3 rounded-xl shadow-lg transition-all duration-200 transform hover:scale-105">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  Create Your First Product
                </.button>
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
              <div class="p-6 max-w-sm mx-auto">
                <div class="text-center">
                  <div class="w-16 h-16 mx-auto mb-4 bg-red-100 rounded-full flex items-center justify-center">
                    <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                    </svg>
                  </div>
                  <h2 class="text-lg font-semibold text-slate-800 mb-2">Delete Product</h2>
                  <p class="text-slate-600 mb-6">Are you sure you want to delete this product? This action cannot be undone.</p>
                  <div class="flex gap-3">
                    <.button phx-click="cancel_delete" class="flex-1 bg-slate-100 hover:bg-slate-200 text-slate-700 border-0">
                      Cancel
                    </.button>
                    <.button phx-click="confirm_delete" class="flex-1 bg-red-600 hover:bg-red-700 text-white">
                      Delete
                    </.button>
                  </div>
                </div>
              </div>
            </.modal>
          <% end %>

          <%= if @page == :profile do %>
            <div class="max-w-2xl mx-auto">
              <div class="mb-8">
                <h1 class="text-3xl font-bold text-slate-800 mb-2">Profile Settings</h1>
                <p class="text-slate-600">Manage your account information and preferences.</p>
              </div>

              <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-8">
                <%= if @current_user.profile_image do %>
                  <div class="flex justify-center mb-8">
                    <div class="relative">
                      <img src={@current_user.profile_image} alt="Profile Image" class="w-32 h-32 rounded-full object-cover border-4 border-blue-100" />
                      <div class="absolute -bottom-2 -right-2 w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center">
                        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536M9 13h3l8-8a2.828 2.828 0 10-4-4l-8 8v3z" />
                        </svg>
                      </div>
                    </div>
                  </div>
                <% end %>

                <.simple_form
                  for={@profile_form}
                  id="profile_form"
                  phx-submit="save_profile"
                  phx-change="validate_profile"
                  class="space-y-6"
                >
                  <.input field={@profile_form[:name]} type="text" label="Full Name" class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500" />
                  <.input field={@profile_form[:bio]} type="textarea" label="Bio" class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500" />
                  <.input
                    field={@profile_form[:profile_image]}
                    type="file"
                    label="Profile Image"
                    accept="image/*"
                    class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500"
                  />
                  <:actions>
                    <.button class="w-full bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white py-3 rounded-xl shadow-lg transition-all duration-200 transform hover:scale-105">
                      Save Changes
                    </.button>
                  </:actions>
                </.simple_form>
              </div>

              <div class="mt-8 text-center">
                <.button phx-click="toggle_password_form" class="bg-slate-100 hover:bg-slate-200 text-slate-700 px-6 py-3 rounded-xl transition-colors">
                  <%= if @show_password_form, do: "Hide Password Change", else: "Change Password" %>
                </.button>
              </div>

              <%= if @show_password_form do %>
                <div class="mt-6 bg-white rounded-2xl shadow-sm border border-slate-100 p-8">
                  <div class="mb-6">
                    <h3 class="text-lg font-semibold text-slate-800 mb-2">Change Password</h3>
                    <p class="text-slate-600 text-sm">Update your password to keep your account secure.</p>
                  </div>

                  <.simple_form
                    for={@password_form}
                    id="password_form"
                    phx-change="validate_password"
                    phx-submit="update_password"
                    class="space-y-6"
                  >
                    <.input field={@password_form[:current_password]} name="current_password" type="password" label="Current Password" value={@current_password} required class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500" />
                    <.input field={@password_form[:password]} type="password" label="New Password" required class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500" />
                    <.input field={@password_form[:password_confirmation]} type="password" label="Confirm New Password" class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500" />
                    <:actions>
                      <.button phx-disable-with="Changing..." class="w-full bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white py-3 rounded-xl shadow-lg transition-all duration-200 transform hover:scale-105">
                        Change Password
                      </.button>
                    </:actions>
                  </.simple_form>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @page == :products do %>
            <.modal :if={@show_view_modal} id="view-product-modal" show on_cancel={JS.push("close_view_modal")}>
              <div class="p-6 max-w-lg mx-auto">
                <div class="flex justify-between items-center mb-6">
                  <h2 class="text-2xl font-bold text-slate-800">Product Details</h2>
                  <button phx-click="close_view_modal" class="text-slate-400 hover:text-slate-600 transition-colors">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                <%= if @view_product do %>
                  <div class="space-y-6">
                    <div class="flex justify-center">
                      <%= if @view_product.image do %>
                        <img src={@view_product.image} alt={@view_product.name} class="w-64 h-64 object-cover rounded-2xl shadow-lg" />
                      <% else %>
                        <div class="w-64 h-64 bg-gradient-to-br from-slate-100 to-slate-200 rounded-2xl flex items-center justify-center">
                          <svg class="w-16 h-16 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                        </div>
                      <% end %>
                    </div>

                    <div class="bg-slate-50 rounded-xl p-6 space-y-4">
                      <div>
                        <span class="text-sm font-medium text-slate-500">Product Name</span>
                        <p class="text-lg font-semibold text-slate-800"><%= @view_product.name %></p>
                      </div>

                      <div>
                        <span class="text-sm font-medium text-slate-500">Description</span>
                        <p class="text-slate-700 leading-relaxed"><%= @view_product.description %></p>
                      </div>

                      <div class="grid grid-cols-2 gap-4">
                        <div>
                          <span class="text-sm font-medium text-slate-500">Price</span>
                          <p class="text-xl font-bold text-green-600">K<%= @view_product.price %></p>
                        </div>

                        <div>
                          <span class="text-sm font-medium text-slate-500">Stock</span>
                          <p class="text-lg font-semibold text-slate-800"><%= @view_product.quantity %> units</p>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </.modal>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
