defmodule HandmadeHubWeb.CheckoutLive do
  use HandmadeHubWeb, :live_view
  
  alias HandmadeHub.{Shopping, Orders, Accounts}
  alias HandmadeHub.Orders.ShippingAddress
  
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

    {:noreply, assign(socket, :shipping_changeset, changeset)}
  end

  @impl true
  def handle_event("save_shipping", %{"shipping_address" => shipping_params}, socket) do
    changeset = Orders.change_shipping_address(%ShippingAddress{}, shipping_params)
    
    if changeset.valid? do
      # Calculate shipping fee based on city
      shipping_fee = calculate_shipping_fee(shipping_params["city"])
      order_total = Decimal.add(socket.assigns.cart_total, shipping_fee)
      
      {:noreply,
       socket
       |> assign(:shipping_address, shipping_params)
       |> assign(:shipping_fee, shipping_fee)
       |> assign(:order_total, order_total)
       |> assign(:current_step, 2)}
    else
      changeset = Map.put(changeset, :action, :validate)
      {:noreply, assign(socket, :shipping_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("select_payment_method", %{"payment_method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  @impl true
  def handle_event("select_mobile_money_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, :mobile_money_provider, provider)}
  end

  @impl true
  def handle_event("update_mobile_number", %{"mobile_number" => number}, socket) do
    {:noreply, assign(socket, :mobile_money_number, number)}
  end

  @impl true
  def handle_event("save_payment", _params, socket) do
    cond do
      socket.assigns.payment_method == nil ->
        {:noreply, put_flash(socket, :error, "Please select a payment method")}
      
      socket.assigns.payment_method == "mobile_money" && 
        (socket.assigns.mobile_money_provider == nil || socket.assigns.mobile_money_number == nil) ->
        {:noreply, put_flash(socket, :error, "Please complete mobile money details")}
      
      socket.assigns.payment_method == "mobile_money" && 
        !valid_phone_number?(socket.assigns.mobile_money_number) ->
        {:noreply, put_flash(socket, :error, "Please enter a valid phone number")}
      
      true ->
        {:noreply, assign(socket, :current_step, 3)}
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
        # Here you would integrate with actual payment provider
        # For now, we'll simulate payment processing
        Process.send_after(self(), {:payment_processed, order.id}, 2000)
        socket
        
      {:error, _changeset} ->
        socket
        |> assign(:processing_payment, false)
        |> put_flash(:error, "Failed to create order. Please try again.")
    end
  end

  @impl true
  def handle_info({:payment_processed, order_id}, socket) do
    # Simulate payment success
    {:ok, order} = Orders.mark_order_as_paid(order_id, "SIM-#{:rand.uniform(999999)}")
    
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
      city when city in ["Lusaka", "Kitwe", "Ndola"] -> Decimal.new("50")
      _ -> Decimal.new("75")
    end
  end

  defp valid_phone_number?(number) do
    Regex.match?(~r/^(0|260)\d{9}$/, number || "")
  end

  def format_price(price) do
    "K#{Decimal.to_string(price)}"
  end
end
