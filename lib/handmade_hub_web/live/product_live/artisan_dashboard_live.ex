defmodule HandmadeHubWeb.ArtisanDashboardLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers
  alias HandmadeHub.ArtisanOrders
  alias HandmadeHub.Catalog
  alias HandmadeHub.Messaging
  alias HandmadeHub.Reviews
  alias HandmadeHub.Payments

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    cond do
      is_nil(user) ->
        {:ok,
         socket
         |> put_flash(:error, "You must be logged in to access this page")
         |> redirect(to: ~p"/users/log_in")}

      user.role != "artisan" ->
        {:ok,
         socket
         |> redirect(to: ~p"/buyer/dashboard")}

      user.artisan_status != "approved" ->
        {:ok,
         socket
         |> put_flash(:info, "Your artisan account is pending approval. Complete your profile while you wait.")
         |> redirect(to: ~p"/users/settings/profile")}

      true ->
        form = HandmadeHub.Accounts.User.profile_changeset(user, %{}) |> to_form()
        password_form = HandmadeHub.Accounts.change_user_password(user) |> to_form()
        socket =
          socket
          |> allow_upload(:profile_image,
            accept: ~w(.jpg .jpeg .png .gif),
            max_entries: 1,
            max_file_size: 5_000_000
          )
        stats = ArtisanOrders.get_artisan_stats(user.id, :this_month)
        active_products_count = HandmadeHub.Catalog.list_user_products(user.id) |> Enum.count(&(&1.quantity > 0))
        avg_rating_float =
          case Reviews.average_all_reviews_for_artisan(user.id) do
            n when is_integer(n) -> n * 1.0
            n when is_float(n) -> n
            _ -> 0.0
          end
        unread_messages = Messaging.unread_count(user.id)
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
          view_selected_image_url: nil,
          sidebar_collapsed: false,
          # Orders related assigns
          orders: [],
          order_stats: stats,
          active_products_count: active_products_count,
          avg_rating: avg_rating_float,
          unread_messages: unread_messages,
          selected_order: nil,
          show_order_modal: false,
          order_filters: %{
            search: "",
            status: "",
            payment_status: ""
          },
          stats_period: :this_month,
          show_print_modal: false,
          # Payouts related assigns
          payouts: [],
          payout_filter_status: nil
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
    user_id = socket.assigns.current_user.id
    stats = ArtisanOrders.get_artisan_stats(user_id, socket.assigns.stats_period)
    active_products_count = HandmadeHub.Catalog.list_user_products(user_id) |> Enum.count(&(&1.quantity > 0))
    {:noreply, assign(socket, page: :dashboard, order_stats: stats, active_products_count: active_products_count)}
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
          {:ok, user} ->
            form = HandmadeHub.Accounts.User.profile_changeset(user, %{}) |> to_form()
            {:noreply,
             socket
             |> assign(:current_user, user)
             |> assign(:profile_form, form)
             |> put_flash(:info, "Profile updated successfully.")}
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
    avg = Reviews.average_product_rating(product.id)
    avg_float = case avg do
      n when is_integer(n) -> n * 1.0
      n when is_float(n) -> n
      _ -> 0.0
    end
    primary = Enum.find(product.product_images || [], &(&1.is_primary)) || List.first(product.product_images || [])
    selected_url = if primary, do: primary.image_url, else: product.image
    {:noreply, assign(socket,
      show_view_modal: true,
      view_product: product,
      view_product_avg: avg_float,
      view_product_reviews: Reviews.list_product_reviews(product.id),
      view_selected_image_url: selected_url
    )}
  end

  def handle_event("close_view_modal", _params, socket) do
    {:noreply, assign(socket, show_view_modal: false, view_product: nil, view_selected_image_url: nil)}
  end

  def handle_event("select_view_image", %{"url" => url}, socket) do
    {:noreply, assign(socket, view_selected_image_url: url)}
  end

  # Orders event handlers
  def handle_event("show_orders", _params, socket) do
    user_id = socket.assigns.current_user.id
    orders = ArtisanOrders.list_artisan_orders(user_id)
    stats = ArtisanOrders.get_artisan_stats(user_id, socket.assigns.stats_period)

    {:noreply, assign(socket,
      page: :orders,
      orders: orders,
      order_stats: stats,
      order_filters: %{
        search: "",
        status: "",
        payment_status: ""
      }
    )}
  end

  def handle_event("show_reviews", _params, socket) do
    user_id = socket.assigns.current_user.id
    reviews = Reviews.list_all_reviews_for_artisan(user_id)
    avg = Reviews.average_all_reviews_for_artisan(user_id)
    avg_float = case avg do
      %Decimal{} = d -> Decimal.to_float(d)
      n when is_integer(n) -> n * 1.0
      n when is_float(n) -> n
      _ -> 0.0
    end
    {:noreply, assign(socket, page: :reviews, artisan_reviews: reviews, avg_rating: avg_float)}
  end

  def handle_event("show_payouts", _params, socket) do
    user_id = socket.assigns.current_user.id
    payouts = Payments.list_payouts(%{artisan_id: user_id})
    {:noreply, assign(socket, page: :payouts, payouts: payouts, payout_filter_status: nil)}
  end

  def handle_event("filter_payouts", %{"status" => status}, socket) do
    user_id = socket.assigns.current_user.id
    filter_status = if status == "", do: nil, else: status
    filters = %{artisan_id: user_id}
    filters = if filter_status, do: Map.put(filters, :status, filter_status), else: filters
    payouts = Payments.list_payouts(filters)
    {:noreply, assign(socket, payouts: payouts, payout_filter_status: filter_status)}
  end

  # New: Messages section handlers
  def handle_event("show_messages", _params, socket) do
    user_id = socket.assigns.current_user.id
    conversations = HandmadeHub.Messaging.list_conversations(user_id)
    {:noreply, assign(socket,
      page: :messages,
      conversations: conversations,
      with_user: nil,
      messages: [],
      message_form: to_form(%{}, as: :message)
    )}
  end

  def handle_event("msg_select_conversation", %{"other_id" => id}, socket) do
    other_id = String.to_integer(id)
    HandmadeHub.Messaging.mark_read(socket.assigns.current_user.id, other_id)
    {:noreply, assign(socket,
      with_user: HandmadeHub.Accounts.get_user!(other_id),
      messages: HandmadeHub.Messaging.list_messages(socket.assigns.current_user.id, other_id)
    )}
  end

  def handle_event("msg_send", %{"message" => %{"body" => body}}, socket) do
    if socket.assigns.with_user do
      {:ok, _} = HandmadeHub.Messaging.send_message(%{
        sender_id: socket.assigns.current_user.id,
        recipient_id: socket.assigns.with_user.id,
        subject: nil,
        body: body
      })
      msgs = HandmadeHub.Messaging.list_messages(socket.assigns.current_user.id, socket.assigns.with_user.id)
      {:noreply, assign(socket, messages: msgs, message_form: to_form(%{}, as: :message))}
    else
      {:noreply, socket}
    end
  end

  # New: Settings section handlers
  def handle_event("show_settings", _params, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket,
      page: :settings,
      settings_email_form: HandmadeHub.Accounts.change_user_email(user) |> to_form(),
      settings_password_form: HandmadeHub.Accounts.change_user_password(user) |> to_form(),
      trigger_submit: false,
      current_password: ""
    )}
  end

  def handle_event("settings_validate_email", %{"user" => params}, socket) do
    form = socket.assigns.current_user |> HandmadeHub.Accounts.change_user_email(params) |> Map.put(:action, :validate) |> to_form()
    {:noreply, assign(socket, settings_email_form: form)}
  end

  def handle_event("settings_update_email", %{"current_password" => pwd, "user" => params}, socket) do
    case HandmadeHub.Accounts.apply_user_email(socket.assigns.current_user, pwd, params) do
      {:ok, applied} ->
        HandmadeHub.Accounts.deliver_user_update_email_instructions(applied, socket.assigns.current_user.email, &url(~p"/users/settings/confirm_email/#{&1}"))
        {:noreply, put_flash(socket, :info, "Confirmation email sent.")}
      {:error, cs} -> {:noreply, assign(socket, settings_email_form: to_form(Map.put(cs, :action, :insert)))}
    end
  end

  def handle_event("settings_validate_password", %{"user" => params}, socket) do
    form = socket.assigns.current_user |> HandmadeHub.Accounts.change_user_password(params) |> Map.put(:action, :validate) |> to_form()
    {:noreply, assign(socket, settings_password_form: form)}
  end

  def handle_event("settings_update_password", %{"current_password" => pwd, "user" => params}, socket) do
    case HandmadeHub.Accounts.update_user_password(socket.assigns.current_user, pwd, params) do
      {:ok, _u} -> {:noreply, put_flash(socket, :info, "Password updated.")}
      {:error, cs} -> {:noreply, assign(socket, settings_password_form: to_form(cs))}
    end
  end

  def handle_event("filter_orders", params, socket) do
    user_id = socket.assigns.current_user.id
    filters = Map.take(params, ["search", "status", "payment_status"])
              |> Enum.filter(fn {_k, v} -> v != "" end)
              |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)

    filtered_orders = ArtisanOrders.list_artisan_orders(user_id, filters)
    {:noreply, assign(socket, orders: filtered_orders, order_filters: filters)}
  end

  def handle_event("view_order", %{"order-id" => order_id}, socket) do
    user_id = socket.assigns.current_user.id
    order = ArtisanOrders.get_artisan_order!(user_id, order_id)
    artisan_items = ArtisanOrders.get_artisan_order_items(user_id, order_id)

    {:noreply, assign(socket,
      show_order_modal: true,
      selected_order: Map.put(order, :artisan_items, artisan_items)
    )}
  end

  def handle_event("close_order_modal", _params, socket) do
    {:noreply, assign(socket, show_order_modal: false, selected_order: nil)}
  end

  def handle_event("filter_stats_period", %{"stats_period" => period}, socket) do
    user_id = socket.assigns.current_user.id
    period_atom = case period do
      "today" -> :today
      "week" -> :this_week
      "month" -> :this_month
      "year" -> :this_year
      "all" -> :all_time
      _ -> :this_month
    end

    stats = ArtisanOrders.get_artisan_stats(user_id, period_atom)
    {:noreply, assign(socket, stats_period: period_atom, order_stats: stats)}
  end

  def handle_event("update_order_status", %{"order_id" => order_id, "status" => status}, socket) do
    user_id = socket.assigns.current_user.id

    case ArtisanOrders.update_artisan_order_status(user_id, order_id, status) do
      {:ok, _order} ->
        orders = ArtisanOrders.list_artisan_orders(user_id, socket.assigns.order_filters)
        stats = ArtisanOrders.get_artisan_stats(user_id, socket.assigns.stats_period)

        {:noreply, socket
         |> put_flash(:info, "Order status updated successfully")
         |> assign(orders: orders, order_stats: stats, show_order_modal: false, selected_order: nil)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("print_report", _params, socket) do
    {:noreply, assign(socket, show_print_modal: true)}
  end

  def handle_event("close_print_modal", _params, socket) do
    {:noreply, assign(socket, show_print_modal: false)}
  end

  defp handle_profile_upload(socket, params) do
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

  defp avatar_url(nil), do: nil
  defp avatar_url(path) when is_binary(path) do
    if String.starts_with?(path, "/") do
      path
    else
      "/uploads/profile_images/" <> path
    end
  end

  defp to_float_rating(avg) do
    cond do
      is_integer(avg) -> avg * 1.0
      is_float(avg) -> avg
      match?(%Decimal{}, avg) -> Decimal.to_float(avg)
      true -> 0.0
    end
  end

  defp product_avg(product_id) do
    Reviews.average_product_rating(product_id) |> to_float_rating()
  end

  defp primary_image_url(nil), do: nil
  defp primary_image_url(%{product_images: imgs}) when is_list(imgs) do
    case Enum.find(imgs, &(&1.is_primary)) || List.first(imgs) do
      nil -> nil
      img -> img.image_url
    end
  end

  @impl true
  def handle_info({HandmadeHubWeb.ProductLive.FormComponent, {:saved, _product}}, socket) do
    # Refresh products after save
    products = HandmadeHub.Catalog.list_user_products(socket.assigns.current_user.id)
    product_streams = %{products: Enum.with_index(products) |> Enum.into(%{}, fn {p, i} -> {i, p} end)}
    action = if socket.assigns.modal_action == :edit, do: "updated", else: "created"
    {:noreply, socket
      |> put_flash(:info, "Product #{action} successfully.")
      |> assign(show_modal: false, modal_action: nil, modal_product: nil, products: products, product_streams: product_streams, page: :products)}
  end

  @impl true
  def handle_info({:refresh_images, _product_id}, socket) do
    products = HandmadeHub.Catalog.list_user_products(socket.assigns.current_user.id)
    {:noreply, assign(socket, products: products)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gradient-to-br from-slate-50 to-blue-50">
      <!-- Enhanced Modern Sidebar -->
      <aside class={[
        "bg-white/95 backdrop-blur-sm border-r border-slate-200/60 flex-shrink-0 transition-all duration-300 ease-in-out shadow-lg",
        "hidden md:block h-screen sticky top-0 overflow-hidden",
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
                aria-label="Toggle sidebar"
                aria-pressed={@sidebar_collapsed}
              >
                <svg class={["w-5 h-5 transition-transform duration-200 transform", @sidebar_collapsed && "rotate-180"]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                  <img src={avatar_url(@current_user.profile_image)} alt="Profile" class="w-12 h-12 rounded-full object-cover ring-2 ring-blue-100" />
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
          <nav class="flex-1 p-4 overflow-y-auto">
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
              <button
                phx-click="show_orders"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :orders && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Orders</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :orders && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Payouts -->
              <button
                phx-click="show_payouts"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :payouts && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Payouts</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :payouts && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Messages -->
              <button
                phx-click="show_messages"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :messages && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Messages</span>
                <%= if @unread_messages && @unread_messages > 0 do %>
                  <span class={[
                    "ml-auto inline-flex items-center justify-center h-5 min-w-[1.25rem] px-1 rounded-full bg-yellow-400 text-indigo-900 text-xs font-bold",
                    @sidebar_collapsed && "hidden"
                  ]}><%= @unread_messages %></span>
                <% end %>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :messages && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Reviews -->
              <button
                phx-click="show_reviews"
                class="w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Reviews</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @sidebar_collapsed && "hidden"]}></div>
              </button>

              <!-- Settings -->
              <button
                phx-click="show_settings"
                class={[
                  "w-full flex items-center px-4 py-3 rounded-xl transition-all duration-200 group",
                  @page == :settings && "bg-blue-50 text-blue-600 shadow-sm" || "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                ]}
              >
                <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.983 13.9a1.9 1.9 0 100-3.8 1.9 1.9 0 000 3.8z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.285 12.972a7.953 7.953 0 000-1.944l2.122-1.55a.5.5 0 00.12-.66l-2-3.464a.5.5 0 00-.607-.218l-2.5 1a7.97 7.97 0 00-1.683-.98l-.375-2.65a.5.5 0 00-.497-.426h-4a.5.5 0 00-.497.426l-.375 2.65c.593-.23 1.157-.57 1.683-.98l2.5 1a.5.5 0 00.607-.218l-2-3.464a.5.5 0 00-.12-.66l-2.122-1.55z" />
                </svg>
                <span class={["ml-3 font-medium", @sidebar_collapsed && "hidden"]}>Settings</span>
                <div class={["ml-auto w-2 h-2 bg-blue-500 rounded-full opacity-0 group-hover:opacity-100 transition-opacity", @page == :settings && "opacity-100", @sidebar_collapsed && "hidden"]}></div>
              </button>
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
                  <span class="text-2xl font-bold text-slate-800"><%= @active_products_count %></span>
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
                  <span class="text-2xl font-bold text-slate-800"><%= @order_stats.pending_orders + @order_stats.processing_orders %></span>
                </div>
                <h3 class="text-sm font-semibold text-slate-600">New Orders</h3>
              </div>

              <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
                <div class="flex items-center justify-between mb-4">
                  <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <span class="text-2xl font-bold text-slate-800"><%= format_currency(@order_stats.total_revenue || Decimal.new(0)) %></span>
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
                  <span class="text-2xl font-bold text-slate-800"><%= :erlang.float_to_binary(@avg_rating || 0.0, decimals: 1) %></span>
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
                  <% img = (Enum.find(product.product_images || [], &(&1.is_primary)) || List.first(product.product_images || [])) %>
                  <%= if img && img.image_url do %>
                    <img src={img.image_url} alt={product.name} class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300">
                  <% else %>
                    <%= if product.image do %>
                      <img src={product.image} alt={product.name} class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300">
                    <% else %>
                      <div class="w-full h-full bg-gradient-to-br from-slate-100 to-slate-200 flex items-center justify-center">
                        <svg class="w-12 h-12 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      </div>
                    <% end %>
                  <% end %>
                  <div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors duration-300"></div>
                  <div class="absolute bottom-2 left-2 flex items-center gap-2 bg-white/80 backdrop-blur px-2 py-1 rounded">
                    <%= if @current_user.profile_image do %>
                      <img src={avatar_url(@current_user.profile_image)} alt="Artisan" class="w-6 h-6 rounded-full object-cover" />
                    <% else %>
                      <div class="w-6 h-6 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center text-white text-[10px] font-semibold">
                        <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
                      </div>
                    <% end %>
                    <span class="text-xs text-slate-700">You</span>
                  </div>
                </div>

                <div class="p-5">
                  <h3 class="text-lg font-semibold text-slate-900 mb-2 line-clamp-1"><%= product.name %></h3>
                  <p class="text-slate-600 text-sm mb-4 line-clamp-2 leading-relaxed"><%= product.description %></p>

                  <div class="flex items-center justify-between mb-4">
                    <span class="text-2xl font-bold text-green-600"><%= format_currency(product.price) %></span>
                    <div class="flex items-center text-sm text-slate-500 gap-3">
                      <div class="flex items-center">
                        <%= for i <- 1..5 do %>
                          <svg class={[
                            "w-4 h-4",
                            (i <= (Float.round(product_avg(product.id) || 0.0) |> trunc)) && "text-yellow-400" || "text-gray-300"
                          ]} fill="currentColor" viewBox="0 0 20 20">
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                          </svg>
                        <% end %>
                        <span class="ml-1 text-xs">(<%= :erlang.float_to_binary(product_avg(product.id) || 0.0, decimals: 1) %>)</span>
                      </div>
                      <div class="flex items-center text-sm text-slate-500">
                        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                        </svg>
                        <%= product.quantity %> in stock
                      </div>
                    </div>
                  </div>

                  <%= if @view_product && @view_product.id == product.id do %>
                    <div class="mb-4 flex items-center gap-2">
                      <div class="flex">
                        <%= for i <- 1..5 do %>
                          <svg class={["w-4 h-4", (i <= (Float.round(@view_product_avg || 0.0) |> trunc)) && "text-yellow-400" || "text-gray-300"]} fill="currentColor" viewBox="0 0 20 20">
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                          </svg>
                        <% end %>
                      </div>
                      <span class="text-xs text-slate-500">(<%= :erlang.float_to_binary(@view_product_avg || 0.0, decimals: 1) %>)</span>
                    </div>
                    <div class="space-y-2 max-h-48 overflow-y-auto">
                      <%= for r <- (@view_product_reviews || []) do %>
                        <div class="text-sm text-slate-700 border-b pb-2">
                          <div class="flex items-center gap-2">
                            <div class="flex">
                              <%= for i <- 1..5 do %>
                                <svg class={["w-3.5 h-3.5", (i <= r.rating) && "text-yellow-400" || "text-gray-300"]} fill="currentColor" viewBox="0 0 20 20">
                                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                                </svg>
                              <% end %>
                            </div>
                            <span class="text-[11px] text-slate-500"><%= Calendar.strftime(r.inserted_at, "%b %d, %Y") %></span>
                          </div>
                          <p><%= r.comment %></p>
                        </div>
                      <% end %>
                      <%= if (@view_product_reviews || []) == [] do %>
                        <div class="text-slate-500 text-sm">No reviews yet.</div>
                      <% end %>
                    </div>
                  <% end %>

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

          <%= if @page == :reviews do %>
            <div class="mb-8">
              <h1 class="text-3xl font-bold text-slate-800 mb-2">Reviews</h1>
              <p class="text-slate-600">What buyers are saying about you.</p>
            </div>

            <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-6 mb-6 flex items-center gap-4">
              <div class="flex">
                <%= for i <- 1..5 do %>
                  <svg class={["w-6 h-6", (i <= (Float.round(@avg_rating || 0.0) |> trunc)) && "text-yellow-400" || "text-gray-300"]} fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                <% end %>
              </div>
              <div class="text-slate-700 text-lg font-semibold"><%= :erlang.float_to_binary(@avg_rating || 0.0, decimals: 1) %></div>
            </div>

            <div class="space-y-4">
              <%= for r <- (@artisan_reviews || []) do %>
                <div class="bg-white rounded-xl shadow-sm border border-slate-100 p-4">
                  <div class="flex items-center gap-2 mb-1">
                    <div class="flex">
                      <%= for i <- 1..5 do %>
                        <svg class={["w-4 h-4", (i <= r.rating) && "text-yellow-400" || "text-gray-300"]} fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                        </svg>
                      <% end %>
                    </div>
                    <span class="text-xs text-slate-500"><%= Calendar.strftime(r.inserted_at, "%b %d, %Y") %></span>
                    <%= if Map.has_key?(r, :user) && r.user do %>
                      <span class="text-xs text-slate-500">• by <%= r.user.name || r.user.email %></span>
                    <% end %>
                  </div>
                  <p class="text-sm text-slate-700"><%= r.comment %></p>
                </div>
              <% end %>
              <%= if (@artisan_reviews || []) == [] do %>
                <div class="text-slate-500">No reviews yet.</div>
              <% end %>
            </div>
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
                      <img src={avatar_url(@current_user.profile_image)} alt="Profile Image" class="w-32 h-32 rounded-full object-cover border-4 border-blue-100" />
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
                  <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Profile Image</label>
                    <.live_file_input upload={@uploads.profile_image} class="rounded-xl border-slate-200 focus:border-blue-500 focus:ring-blue-500" />
                  </div>
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
                    <div class="flex flex-col items-center gap-4">
                      <% main_img = @view_selected_image_url || primary_image_url(@view_product) || @view_product.image %>
                      <div class="flex justify-center">
                        <%= if main_img do %>
                          <img src={main_img} alt={@view_product.name} class="w-64 h-64 object-cover rounded-2xl shadow-lg" />
                        <% else %>
                          <div class="w-64 h-64 bg-gradient-to-br from-slate-100 to-slate-200 rounded-2xl flex items-center justify-center">
                            <svg class="w-16 h-16 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2z" />
                            </svg>
                          </div>
                        <% end %>
                      </div>

                      <div class="w-full overflow-x-auto">
                        <div class="flex gap-3 min-w-max px-1">
                          <%= for img <- (@view_product.product_images || []) do %>
                            <button phx-click="select_view_image" phx-value-url={img.image_url} class={[
                              "w-20 h-20 rounded-lg overflow-hidden border transition ring-offset-2",
                              (img.is_primary || img.image_url == @view_selected_image_url) && "ring-2 ring-blue-500 border-blue-400" || "border-slate-200 hover:border-slate-400"
                            ]}>
                              <img src={img.image_url} alt="Thumbnail" class="w-full h-full object-cover" />
                            </button>
                          <% end %>
                        </div>
                      </div>
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
                          <p class="text-xl font-bold text-green-600"><%= format_currency(@view_product.price) %></p>
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

          <!-- Orders Page -->
          <%= if @page == :orders do %>
            <div class="space-y-8">
              <!-- Orders Header with Stats Period Selector -->
              <div class="flex justify-between items-center">
                <div>
                  <h1 class="text-3xl font-bold text-gray-900">Orders Management</h1>
                  <p class="text-gray-600 mt-1">Track and manage your product orders</p>
                </div>
                <div class="flex items-center space-x-4">
                  <select
                    phx-change="filter_stats_period"
                    name="stats_period"
                    class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="today" selected={@stats_period == "today"}>Today</option>
                    <option value="week" selected={@stats_period == "week"}>This Week</option>
                    <option value="month" selected={@stats_period == "month"}>This Month</option>
                    <option value="year" selected={@stats_period == "year"}>This Year</option>
                    <option value="all" selected={@stats_period == "all"}>All Time</option>
                  </select>
                  <button
                    phx-click="print_report"
                    class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center space-x-2"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                    </svg>
                    <span>Print Report</span>
                  </button>
                </div>
              </div>

              <!-- Statistics Cards -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <!-- Total Orders Card -->
                <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-gray-600">Total Orders</p>
                      <p class="text-3xl font-bold text-gray-900 mt-2"><%= @order_stats.total_orders %></p>
                    </div>
                    <div class="p-3 bg-blue-100 rounded-lg">
                      <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
                      </svg>
                    </div>
                  </div>
                </div>

                <!-- Revenue Card -->
                <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-gray-600">Total Revenue</p>
                      <p class="text-3xl font-bold text-green-600 mt-2"><%= format_currency(@order_stats.total_revenue || Decimal.new(0)) %></p>
                    </div>
                    <div class="p-3 bg-green-100 rounded-lg">
                      <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                  </div>
                </div>

                <!-- Pending Orders Card -->
                <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-gray-600">Pending Orders</p>
                      <p class="text-3xl font-bold text-yellow-600 mt-2"><%= @order_stats.pending_orders %></p>
                    </div>
                    <div class="p-3 bg-yellow-100 rounded-lg">
                      <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                  </div>
                </div>

                <!-- Completed Orders Card -->
                <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-gray-600">Completed Orders</p>
                      <p class="text-3xl font-bold text-purple-600 mt-2"><%= @order_stats.completed_orders %></p>
                    </div>
                    <div class="p-3 bg-purple-100 rounded-lg">
                      <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Best Sellers Section -->
              <%= if @order_stats.best_sellers && length(@order_stats.best_sellers) > 0 do %>
                <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Best Selling Products</h3>
                  <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                    <%= for product <- Enum.take(@order_stats.best_sellers, 5) do %>
                      <div class="text-center">
                        <p class="font-medium text-gray-900 truncate"><%= product.product_name %></p>
                        <p class="text-2xl font-bold text-blue-600"><%= product.quantity_sold %></p>
                        <p class="text-sm text-gray-500">units sold</p>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Orders Filter Section -->
              <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                <div class="flex flex-wrap gap-4 items-end">
                  <div class="flex-1 min-w-[200px]">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Search</label>
                    <input
                      type="text"
                      phx-change="filter_orders"
                      phx-debounce="300"
                      name="search"
                      value={Map.get(@order_filters, :search, "")}
                      placeholder="Order #, customer name..."
                      class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                    <select
                      phx-change="filter_orders"
                      name="status"
                      class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">All Status</option>
                      <option value="pending" selected={Map.get(@order_filters, :status) == "pending"}>Pending</option>
                      <option value="processing" selected={Map.get(@order_filters, :status) == "processing"}>Processing</option>
                      <option value="shipped" selected={Map.get(@order_filters, :status) == "shipped"}>Shipped</option>
                      <option value="delivered" selected={Map.get(@order_filters, :status) == "delivered"}>Delivered</option>
                      <option value="cancelled" selected={Map.get(@order_filters, :status) == "cancelled"}>Cancelled</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Payment</label>
                    <select
                      phx-change="filter_orders"
                      name="payment_status"
                      class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">All Payments</option>
                      <option value="paid" selected={Map.get(@order_filters, :payment_status) == "paid"}>Paid</option>
                      <option value="pending" selected={Map.get(@order_filters, :payment_status) == "pending"}>Pending</option>
                      <option value="failed" selected={Map.get(@order_filters, :payment_status) == "failed"}>Failed</option>
                    </select>
                  </div>
                </div>
              </div>

              <!-- Orders Table -->
              <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Order #
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Customer
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Date
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Status
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Payment
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Total
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Actions
                        </th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= if @orders && length(@orders) > 0 do %>
                        <%= for order <- @orders do %>
                          <tr class="hover:bg-gray-50 transition-colors">
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              <%= order.order_number %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= order.customer_name || "N/A" %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= Calendar.strftime(order.inserted_at, "%b %d, %Y") %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <span class={[
                                "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                                order.status == "pending" && "bg-yellow-100 text-yellow-800",
                                order.status == "processing" && "bg-blue-100 text-blue-800",
                                order.status == "shipped" && "bg-purple-100 text-purple-800",
                                order.status == "delivered" && "bg-green-100 text-green-800",
                                order.status == "cancelled" && "bg-red-100 text-red-800"
                              ]}>
                                <%= String.capitalize(order.status) %>
                              </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <span class={[
                                "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                                order.payment_status == "paid" && "bg-green-100 text-green-800",
                                order.payment_status == "pending" && "bg-yellow-100 text-yellow-800",
                                order.payment_status == "failed" && "bg-red-100 text-red-800"
                              ]}>
                                <%= String.capitalize(order.payment_status) %>
                              </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">
                              <%= format_currency(order.total || Decimal.new(0)) %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                              <button
                                phx-click="view_order"
                                phx-value-order-id={order.id}
                                class="text-blue-600 hover:text-blue-900 mr-3"
                              >
                                View
                              </button>
                              <button
                                phx-click="update_order_status"
                                phx-value-order-id={order.id}
                                class="text-green-600 hover:text-green-900"
                              >
                                Update
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      <% else %>
                        <tr>
                          <td colspan="7" class="px-6 py-12 text-center text-gray-500">
                            <svg class="mx-auto h-12 w-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                            </svg>
                            <p class="text-lg font-medium">No orders found</p>
                            <p class="text-sm text-gray-400 mt-1">Orders for your products will appear here</p>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>

              <!-- Order Details Modal -->
              <%= if @show_order_modal && @selected_order do %>
                <.modal id="order-details-modal" show on_cancel={JS.push("close_order_modal")}>
                  <div class="p-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-4">Order Details</h3>
                    <div class="space-y-4">
                      <div class="grid grid-cols-2 gap-4">
                        <div>
                          <p class="text-sm text-gray-500">Order Number</p>
                          <p class="font-medium"><%= @selected_order.order_number %></p>
                        </div>
                        <div>
                          <p class="text-sm text-gray-500">Date</p>
                          <p class="font-medium"><%= Calendar.strftime(@selected_order.inserted_at, "%B %d, %Y") %></p>
                        </div>
                      </div>

                      <div>
                        <p class="text-sm text-gray-500 mb-2">Items</p>
                        <div class="border rounded-lg p-4 space-y-2">
                          <%= for item <- @selected_order.order_items do %>
                            <div class="flex justify-between">
                              <span><%= item.product.name %> x <%= item.quantity %></span>
                              <span class="font-medium"><%= format_currency(item.subtotal || Decimal.new(0)) %></span>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <div class="border-t pt-4">
                        <div class="flex justify-between font-semibold">
                          <span>Total</span>
                          <span><%= format_currency(@selected_order.total || Decimal.new(0)) %></span>
                        </div>
                      </div>
                    </div>
                  </div>
                </.modal>
              <% end %>

              <!-- Print Report Modal -->
              <%= if @show_print_modal do %>
                <.modal id="print-report-modal" show on_cancel={JS.push("close_print_modal")}>
                  <div class="p-6" id="print-content">
                    <style type="text/css" media="print">
                      @media print {
                        body * { visibility: hidden; }
                        #print-content, #print-content * { visibility: visible; }
                        #print-content { position: absolute; left: 0; top: 0; }
                      }
                    </style>

                    <div class="text-center mb-6">
                      <h2 class="text-2xl font-bold">Order Report</h2>
                      <p class="text-gray-600">Period: <%= @stats_period %></p>
                      <p class="text-gray-600">Generated: <%= Calendar.strftime(DateTime.utc_now(), "%B %d, %Y") %></p>
                    </div>

                    <div class="space-y-6">
                      <div class="grid grid-cols-2 gap-4">
                        <div class="border rounded p-4">
                          <p class="text-sm text-gray-500">Total Orders</p>
                          <p class="text-2xl font-bold"><%= @order_stats.total_orders %></p>
                        </div>
                        <div class="border rounded p-4">
                          <p class="text-sm text-gray-500">Total Revenue</p>
                          <p class="text-2xl font-bold"><%= format_currency(@order_stats.total_revenue || Decimal.new(0)) %></p>
                        </div>
                      </div>

                      <button
                        onclick="window.print()"
                        class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                      >
                        Print Report
                      </button>
                    </div>
                  </div>
                </.modal>
              <% end %>
            </div>
          <% end %>

          <%= if @page == :messages do %>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="md:col-span-1 bg-white rounded-2xl shadow-sm border border-slate-100 p-4">
                <h2 class="text-lg font-semibold mb-3 text-slate-800">Conversations</h2>
                <div class="space-y-2">
                  <%= for c <- (@conversations || []) do %>
                    <button phx-click="msg_select_conversation" phx-value-other_id={c.other_id} class="w-full text-left px-3 py-2 rounded-lg hover:bg-slate-50">
                      <div class="flex items-center justify-between">
                        <span class="font-medium text-slate-700"><%= HandmadeHub.Accounts.get_user!(c.other_id).name || HandmadeHub.Accounts.get_user!(c.other_id).email %></span>
                        <span class="text-xs text-slate-400"><%= Calendar.strftime(c.last_message.inserted_at, "%b %d") %></span>
                      </div>
                      <p class="text-sm text-slate-500 truncate"><%= c.last_message.body %></p>
                    </button>
                  <% end %>
                  <%= if (@conversations || []) == [] do %>
                    <div class="text-slate-500">No conversations yet.</div>
                  <% end %>
                </div>
              </div>
              <div class="md:col-span-2 bg-white rounded-2xl shadow-sm border border-slate-100 p-4">
                <%= if @with_user do %>
                  <div class="border-b pb-3 mb-4">
                    <h3 class="font-semibold text-slate-800"><%= @with_user.name || @with_user.email %></h3>
                  </div>
                  <div class="space-y-3 max-h-[50vh] overflow-y-auto pr-2">
                    <%= for m <- (@messages || []) do %>
                      <div class={[
                        "px-4 py-2 rounded-xl max-w-[80%]",
                        m.sender_id == @current_user.id && "ml-auto bg-blue-600 text-white" || "bg-slate-100 text-slate-800"
                      ]}>
                        <p class="text-sm"><%= m.body %></p>
                        <div class="text-[10px] opacity-70 mt-1"><%= Calendar.strftime(m.inserted_at, "%b %d, %H:%M") %></div>
                      </div>
                    <% end %>
                  </div>
                  <.simple_form for={@message_form} phx-submit="msg_send" class="mt-4 flex gap-2">
                    <.input field={@message_form[:body]} class="flex-1" placeholder="Type a message..." />
                    <:actions>
                      <.button>Send</.button>
                    </:actions>
                  </.simple_form>
                <% else %>
                  <div class="text-slate-500">Select a conversation to start messaging.</div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @page == :settings do %>
            <div class="max-w-3xl mx-auto space-y-8">
              <div>
                <h1 class="text-3xl font-bold text-slate-800 mb-2">Account Settings</h1>
                <p class="text-slate-600">Manage your account and security.</p>
              </div>

              <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-8">
                <h2 class="text-lg font-semibold text-slate-800 mb-4">Update Email</h2>
                <.simple_form for={@settings_email_form} id="settings_email_form" phx-change="settings_validate_email" phx-submit="settings_update_email" class="space-y-4">
                  <.input field={@settings_email_form[:email]} type="email" label="New email" />
                  <.input name="current_password" type="password" label="Current password" value={@current_password} />
                  <:actions>
                    <.button>Change email</.button>
                  </:actions>
                </.simple_form>
              </div>

              <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-8">
                <h2 class="text-lg font-semibold text-slate-800 mb-4">Update Password</h2>
                <.simple_form for={@settings_password_form} id="settings_password_form" phx-change="settings_validate_password" phx-submit="settings_update_password" class="space-y-4">
                  <.input name="current_password" type="password" label="Current password" value={@current_password} />
                  <.input field={@settings_password_form[:password]} type="password" label="New password" />
                  <.input field={@settings_password_form[:password_confirmation]} type="password" label="Confirm new password" />
                  <:actions>
                    <.button>Change password</.button>
                  </:actions>
                </.simple_form>
              </div>
            </div>
          <% end %>

          <%= if @page == :payouts do %>
            <div class="space-y-8">
              <div>
                <h1 class="text-3xl font-bold text-slate-800 mb-2">My Payouts</h1>
                <p class="text-slate-600">Track your payment history and earnings</p>
              </div>

              <!-- Payout Stats Cards -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="bg-white rounded-xl shadow-sm p-6 border border-slate-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-slate-600">Total Payouts</p>
                      <p class="text-3xl font-bold text-slate-800 mt-2"><%= length(@payouts) %></p>
                    </div>
                    <div class="p-3 bg-blue-100 rounded-lg">
                      <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                    </div>
                  </div>
                </div>

                <div class="bg-white rounded-xl shadow-sm p-6 border border-slate-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-slate-600">Total Earned</p>
                      <p class="text-3xl font-bold text-green-600 mt-2">
                        <%= format_currency(
                          @payouts
                          |> Enum.filter(&(&1.status == "completed"))
                          |> Enum.reduce(Decimal.new("0"), fn p, acc -> Decimal.add(acc, p.net_amount || Decimal.new("0")) end)
                        ) %>
                      </p>
                    </div>
                    <div class="p-3 bg-green-100 rounded-lg">
                      <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                  </div>
                </div>

                <div class="bg-white rounded-xl shadow-sm p-6 border border-slate-100">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium text-slate-600">Pending</p>
                      <p class="text-3xl font-bold text-yellow-600 mt-2">
                        <%= @payouts
                        |> Enum.filter(&(&1.status in ["pending", "processing"]))
                        |> length() %>
                      </p>
                    </div>
                    <div class="p-3 bg-yellow-100 rounded-lg">
                      <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Filter Section -->
              <div class="bg-white rounded-xl shadow-sm p-6 border border-slate-100">
                <div class="flex items-center gap-4">
                  <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
                    <select
                      phx-change="filter_payouts"
                      name="status"
                      class="px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
                    >
                      <option value="">All Statuses</option>
                      <option value="pending" selected={@payout_filter_status == "pending"}>Pending</option>
                      <option value="processing" selected={@payout_filter_status == "processing"}>Processing</option>
                      <option value="completed" selected={@payout_filter_status == "completed"}>Completed</option>
                      <option value="failed" selected={@payout_filter_status == "failed"}>Failed</option>
                    </select>
                  </div>
                </div>
              </div>

              <!-- Payouts Table -->
              <div class="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-slate-200">
                    <thead class="bg-slate-50">
                      <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Payout ID
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Period
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Gross Amount
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Platform Fee
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Net Amount
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Status
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                          Date
                        </th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-slate-200">
                      <%= if @payouts && length(@payouts) > 0 do %>
                        <%= for payout <- @payouts do %>
                          <tr class="hover:bg-slate-50 transition-colors">
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-slate-900">
                              #<%= payout.id %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                              <%= payout.payment_period || "N/A" %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-900">
                              <%= format_currency(payout.amount || Decimal.new("0")) %> <%= payout.currency %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                              <%= format_currency(payout.platform_fee || Decimal.new("0")) %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-slate-900">
                              <%= format_currency(payout.net_amount || Decimal.new("0")) %> <%= payout.currency %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <span class={[
                                "px-2.5 py-1 text-xs font-medium rounded-full",
                                payout.status == "completed" && "bg-green-50 text-green-700",
                                payout.status == "processing" && "bg-blue-50 text-blue-700",
                                payout.status == "pending" && "bg-yellow-50 text-yellow-700",
                                payout.status == "failed" && "bg-red-50 text-red-700"
                              ]}>
                                <%= String.capitalize(payout.status) %>
                              </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-600">
                              <%= if payout.completed_at do %>
                                <%= Calendar.strftime(payout.completed_at, "%Y-%m-%d") %>
                              <% else %>
                                <%= Calendar.strftime(payout.scheduled_date || payout.inserted_at, "%Y-%m-%d") %>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      <% else %>
                        <tr>
                          <td colspan="7" class="px-6 py-12 text-center text-slate-500">
                            <svg class="mx-auto h-12 w-12 text-slate-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                            </svg>
                            <p class="text-lg font-medium">No payouts found</p>
                            <p class="text-sm text-slate-400 mt-1">
                              <%= if @payout_filter_status, do: "Try adjusting your filters", else: "Your payout history will appear here" %>
                            </p>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
