defmodule HandmadeHubWeb.CheckoutLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.{Shopping, Orders, Payments}
  alias HandmadeHub.Orders.ShippingAddress

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h1 class="text-2xl font-bold text-gray-900 mb-6">Checkout</h1>

        <div class="mb-6 flex items-center gap-3 text-sm">
          <div class={["px-3 py-1 rounded-full",
            @current_step >= 1 && "bg-indigo-600 text-white" || "bg-gray-200 text-gray-700"]}>1. Delivery Details</div>
          <div class={["px-3 py-1 rounded-full",
            @current_step >= 2 && "bg-indigo-600 text-white" || "bg-gray-200 text-gray-700"]}>2. Payment</div>
          <div class={["px-3 py-1 rounded-full",
            @current_step >= 3 && "bg-indigo-600 text-white" || "bg-gray-200 text-gray-700"]}>3. Review</div>
        </div>

        <%= if @current_step == 1 do %>
          <div class="bg-white rounded-xl border p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Delivery Details</h2>
            <.form for={@shipping_form} as={:shipping_address} id="shipping_form" phx-change="validate_shipping" phx-submit="save_shipping" class="grid grid-cols-1 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">Recipient Name <span class="text-red-600">*</span></label>
                <input name={@shipping_form[:recipient_name].name} type="text" value={Phoenix.HTML.Form.input_value(@shipping_form, :recipient_name)} required class={[
                  "mt-1 w-full rounded-lg",
                  @shipping_changeset.errors[:recipient_name] && "border-red-500" || "border-gray-300"
                ]} />
                <%= if @shipping_changeset.errors[:recipient_name] do %>
                  <p class="text-xs text-red-600 mt-1">Recipient name is required</p>
                <% end %>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">Recipient Email</label>
                <input name={@shipping_form[:recipient_email].name} type="email" value={Phoenix.HTML.Form.input_value(@shipping_form, :recipient_email)} class="mt-1 w-full border-gray-300 rounded-lg" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">Phone Number <span class="text-red-600">*</span></label>
                <input name={@shipping_form[:phone_number].name} type="tel" value={Phoenix.HTML.Form.input_value(@shipping_form, :phone_number)} required class={[
                  "mt-1 w-full rounded-lg",
                  @shipping_changeset.errors[:phone_number] && "border-red-500" || "border-gray-300"
                ]} />
                <%= if @shipping_changeset.errors[:phone_number] do %>
                  <p class="text-xs text-red-600 mt-1">Enter a valid Zambian number (0/260 + 9 digits)</p>
                <% end %>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">Address Line 1 <span class="text-red-600">*</span></label>
                <input name={@shipping_form[:address_line_1].name} type="text" value={Phoenix.HTML.Form.input_value(@shipping_form, :address_line_1)} required class={[
                  "mt-1 w-full rounded-lg",
                  @shipping_changeset.errors[:address_line_1] && "border-red-500" || "border-gray-300"
                ]} />
                <%= if @shipping_changeset.errors[:address_line_1] do %>
                  <p class="text-xs text-red-600 mt-1">Address is required</p>
                <% end %>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">Address Line 2 (optional)</label>
                <input name={@shipping_form[:address_line_2].name} type="text" class="mt-1 w-full border-gray-300 rounded-lg" />
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Suburb / Residential Area</label>
                  <select name={@shipping_form[:city].name} required class={[
                    "mt-1 w-full rounded-lg",
                    @shipping_changeset.errors[:city] && "border-red-500" || "border-gray-300"
                  ]}>
                    <option value="">Select Suburb</option>
                    <%= for city <- @common_cities do %>
                      <option value={city} selected={Phoenix.HTML.Form.input_value(@shipping_form, :city) == city}><%= city %></option>
                    <% end %>
                  </select>
                  <%= if @shipping_changeset.errors[:city] do %>
                    <p class="text-xs text-red-600 mt-1">Please select a suburb</p>
                  <% end %>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">Delivery Instructions (optional)</label>
                <textarea name={@shipping_form[:delivery_instructions].name} class="mt-1 w-full border-gray-300 rounded-lg" rows="3" placeholder="Gate code, landmark, preferred time, etc."></textarea>
              </div>
              <div class="flex justify-end">
                <button class="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">Continue to Payment</button>
              </div>
            </.form>
          </div>
        <% end %>

        <%= if @current_step == 2 do %>
          <div class="bg-white rounded-xl border p-6 space-y-4">
            <h2 class="text-lg font-semibold text-gray-900">Payment</h2>
            <div class="space-y-2">
              <label class="block text-sm font-medium text-gray-700">Payment Method</label>
              <div class="flex gap-3">
                <button phx-click="select_payment_method" phx-value-payment_method="mobile_money" class={["px-4 py-2 rounded-lg border text-sm",
                  @payment_method == "mobile_money" && "bg-indigo-600 text-white border-indigo-600" || "bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100"]}>Pay with Mobile Money</button>
                <button phx-click="select_payment_method" phx-value-payment_method="cod" class={["px-4 py-2 rounded-lg border text-sm",
                  @payment_method == "cod" && "bg-indigo-600 text-white border-indigo-600" || "bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100"]}>Cash on Delivery</button>
              </div>
            </div>

            <%= if @payment_method == "mobile_money" do %>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Provider</label>
                  <select name="provider" phx-change="select_mobile_money_provider" class="mt-1 w-full border-gray-300 rounded-lg">
                    <option value="">Select Provider</option>
                    <option value="airtel" selected={@mobile_money_provider == "airtel"}>Airtel Money</option>
                    <option value="mtn" selected={@mobile_money_provider == "mtn"}>MTN Mobile Money</option>
                    <option value="zamtel" selected={@mobile_money_provider == "zamtel"}>Zamtel Kwacha</option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Mobile Number</label>
                  <form phx-change="update_mobile_number">
                    <input type="tel" name="mobile_number" value={@mobile_money_number} phx-debounce="300" placeholder="e.g. 0977xxxxxx or 26097xxxxxx" class="mt-1 w-full border-gray-300 rounded-lg" />
                  </form>
                </div>
              </div>
            <% end %>

            <div class="flex justify-between">
              <button phx-click="back_to_shipping" class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200">Back</button>
              <button phx-click="save_payment" class={[
                "px-6 py-2 rounded-lg",
                @can_continue_payment && "bg-indigo-600 text-white hover:bg-indigo-700" || "bg-gray-300 text-gray-500 cursor-not-allowed"
              ]} disabled={!@can_continue_payment}>Continue</button>
            </div>
          </div>
        <% end %>

        <%= if @current_step == 3 do %>
          <div class="bg-white rounded-xl border p-6 space-y-4">
            <h2 class="text-lg font-semibold text-gray-900">Review & Confirm</h2>
            <div class="text-sm text-gray-700">Subtotal: <span class="font-semibold"><%= format_currency(@cart_total) %></span></div>
            <div class="text-sm text-gray-700">Delivery Fee: <span class="font-semibold"><%= format_currency(@shipping_fee) %></span></div>
            <div class="text-base font-semibold text-indigo-700">Total: <%= format_currency(@order_total) %></div>
            <div class="flex justify-between">
              <button phx-click="back_to_payment" class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200">Back</button>
              <button phx-click="place_order" class="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700" disabled={@processing_payment}>Place Order</button>
            </div>
          </div>
        <% end %>

        <%= if @current_step == 4 do %>
          <div class="bg-white rounded-xl border p-6 space-y-4">
            <h2 class="text-lg font-semibold text-gray-900">Order Placed</h2>
            <p class="text-gray-700">Thank you! Your order has been confirmed.</p>
            <div>
              <.link navigate={~p"/orders"} class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">Go to My Orders</.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    cart = get_cart(socket, session)

    if cart && length(Shopping.list_cart_items(cart.id)) > 0 do
      socket =
        socket
        |> assign(:page_title, "Checkout")
        |> assign(:cart, cart)
        |> assign(:cart_items, Shopping.list_cart_items(cart.id))
        |> assign(:cart_total, Shopping.calculate_cart_total(cart.id))
        |> assign(:current_step, 1)
        |> assign(:shipping_changeset, Orders.change_shipping_address(%ShippingAddress{}))
        |> assign(:shipping_form, to_form(Orders.change_shipping_address(%ShippingAddress{})))
        |> assign(:shipping_address, nil)
        |> assign(:payment_method, nil)
        |> assign(:mobile_money_provider, nil)
        |> assign(:mobile_money_number, nil)
        |> assign(:shipping_fee, Decimal.new("0"))
        |> assign(:order_total, Shopping.calculate_cart_total(cart.id))
        |> assign(:provinces, ShippingAddress.provinces())
        |> assign(:common_cities, ShippingAddress.common_cities())
        |> assign(:processing_payment, false)
        |> assign(:order, nil)
        |> assign(:can_continue_payment, false)
        |> assign(:show_payment_errors, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Your cart is empty")
       |> redirect(to: ~p"/cart")}
    end
  end

  @impl true
  def handle_event("validate_shipping", %{"shipping_address" => shipping_params}, socket) do
    changeset =
      %ShippingAddress{}
      |> Orders.change_shipping_address(shipping_params)
      |> Map.put(:action, :validate)
    {:noreply,
     socket
     |> assign(:shipping_changeset, changeset)
     |> assign(:shipping_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_shipping", %{"shipping_address" => shipping_params}, socket) do
    changeset = Orders.change_shipping_address(%ShippingAddress{}, shipping_params)

    if changeset.valid? do
      # Calculate shipping fee based on city
      shipping_fee = calculate_shipping_fee(shipping_params["city"]) # kept function name but UI uses Delivery
      order_total = Decimal.add(socket.assigns.cart_total, shipping_fee)

      {:noreply,
       socket
       |> assign(:shipping_address, shipping_params)
       |> assign(:shipping_fee, shipping_fee)
       |> assign(:order_total, order_total)
       |> assign(:current_step, 2)}
    else
      changeset = Map.put(changeset, :action, :validate)
      {:noreply, assign(socket, shipping_changeset: changeset, shipping_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("select_payment_method", %{"payment_method" => method}, socket) do
    socket = assign(socket, :payment_method, method)
    {:noreply, assign(socket, :can_continue_payment, payment_ready?(socket.assigns))}
  end

  @impl true
  def handle_event("select_mobile_money_provider", %{"provider" => provider}, socket) do
    socket = assign(socket, :mobile_money_provider, provider)
    assigns = %{socket.assigns | mobile_money_provider: provider}
    {:noreply, assign(socket, :can_continue_payment, payment_ready?(assigns))}
  end

  @impl true
  def handle_event("update_mobile_number", %{"mobile_number" => number}, socket) do
    socket = assign(socket, :mobile_money_number, number)
    assigns = %{socket.assigns | mobile_money_number: number}
    {:noreply, assign(socket, :can_continue_payment, payment_ready?(assigns))}
  end

  @impl true
  def handle_event("save_payment", _params, socket) do
    if payment_ready?(socket.assigns) do
      {:noreply, assign(socket, :current_step, 3)}
    else
      {:noreply,
       socket
       |> assign(:show_payment_errors, true)
       |> put_flash(:error, "Please complete required payment fields")}
    end
  end

  @impl true
  def handle_event("place_order", _params, socket) do
    {:noreply,
     socket
     |> assign(:processing_payment, true)
     |> process_order()}
  end

  @impl true
  def handle_event("back_to_shipping", _params, socket) do
    {:noreply, assign(socket, :current_step, 1)}
  end

  @impl true
  def handle_event("back_to_payment", _params, socket) do
    {:noreply, assign(socket, :current_step, 2)}
  end

  defp process_order(socket) do
    user = socket.assigns.current_user

    payment_attrs = %{
      "payment_method" => socket.assigns.payment_method,
      "mobile_money_provider" => socket.assigns.mobile_money_provider,
      "mobile_money_number" => socket.assigns.mobile_money_number,
      "customer_email" => user && user.email || socket.assigns.shipping_address["recipient_email"],
      "customer_phone" => socket.assigns.shipping_address["phone_number"],
      "customer_name" => socket.assigns.shipping_address["recipient_name"]
    }

    case Orders.create_order_from_cart_id(
      socket.assigns.cart.id,
      user,
      socket.assigns.shipping_address,
      payment_attrs
    ) do
      {:ok, order} ->
        # Create deposit and get payment page URL
        return_url = url(~p"/checkout/return?order_id=#{order.id}")

        case Payments.create_deposit(order, payment_attrs, return_url) do
          {:ok, redirect_url} ->
            Phoenix.LiveView.redirect(socket, external: redirect_url)

          {:error, msg} ->
            socket
            |> assign(:processing_payment, false)
            |> put_flash(:error, msg)
        end

      {:error, _changeset} ->
        socket
        |> assign(:processing_payment, false)
        |> put_flash(:error, "Failed to create order. Please try again.")
    end
  end

  @impl true
  def handle_info({:payment_processed, order_id}, socket) do
    {:ok, order} = Orders.mark_order_as_paid(order_id, "PAWA-RETURN")
    {:noreply,
     socket
     |> assign(:processing_payment, false)
     |> assign(:order, order)
     |> assign(:current_step, 4)
     |> put_flash(:info, "Payment successful! Your order has been placed.")}
  end


  defp get_cart(socket, session) do
    user_id = if socket.assigns[:current_user], do: socket.assigns.current_user.id, else: nil
    session_id = Map.get(session, "session_uuid", generate_session_id())

    case Shopping.get_or_create_cart(user_id, session_id) do
      {:ok, cart} -> cart
      _ -> nil
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp calculate_shipping_fee(city) do
    case city do
      city when city in ["Lusaka", "Makeni", "Woodlands", "Northmead", "Kabulonga", "Chalala", "Kanyama", "Chilenje", "Roma", "Rhodespark", "Bauleni", "Chelston", "Garden", "Matero"] -> Decimal.new("30")
      _ -> Decimal.new("75")
    end
  end

  defp valid_phone_number?(number) do
    Regex.match?(~r/^(0|260)\d{9}$/, number || "")
  end

  defp payment_ready?(assigns) do
    case assigns.payment_method do
      nil -> false
      "cod" -> true
      "mobile_money" ->
        provider_ok = not is_nil(assigns.mobile_money_provider) and assigns.mobile_money_provider != ""
        number_ok = valid_phone_number?(assigns.mobile_money_number)
        provider_ok and number_ok
      _ -> false
    end
  end

  # Use imported HandmadeHubWeb.FormatHelpers.format_price/1
end
