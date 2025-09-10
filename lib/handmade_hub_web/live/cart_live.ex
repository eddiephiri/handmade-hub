defmodule HandmadeHubWeb.CartLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.Shopping

  @impl true
  def mount(params, session, socket) do
    cart = get_or_create_cart(socket, session)

    socket =
      socket
      |> assign(:cart, cart)
      |> assign(:cart_items, Shopping.list_cart_items(cart.id))
      |> assign(:cart_total, Shopping.calculate_cart_total(cart.id))
      |> assign(:page_title, "Shopping Cart")
      |> assign(:from_dashboard, Map.get(params, "from") == "dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_event("update_quantity", %{"item_id" => item_id, "quantity" => quantity}, socket) do
    item_id = String.to_integer(item_id)
    quantity = String.to_integer(quantity)

    case Shopping.update_cart_item_quantity(item_id, quantity) do
      {:ok, _item} ->
        {:noreply, reload_cart(socket)}

      {:error, :insufficient_stock} ->
        {:noreply, put_flash(socket, :error, "Not enough stock available")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update quantity")}
    end
  end

  @impl true
  def handle_event("remove_item", %{"item_id" => item_id}, socket) do
    item_id = String.to_integer(item_id)
    case Shopping.remove_from_cart(item_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_cart()
         |> put_flash(:info, "Item removed from cart")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove item")}
    end
  end

  @impl true
  def handle_event("inc_qty", %{"item_id" => item_id}, socket) do
    item_id = String.to_integer(item_id)
    item = Enum.find(socket.assigns.cart_items, &(&1.id == item_id))
    if item do
      case Shopping.update_cart_item_quantity(item_id, item.quantity + 1) do
        {:ok, _} -> {:noreply, reload_cart(socket)}
        {:error, :insufficient_stock} -> {:noreply, put_flash(socket, :error, "Not enough stock available")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to update quantity")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dec_qty", %{"item_id" => item_id}, socket) do
    item_id = String.to_integer(item_id)
    item = Enum.find(socket.assigns.cart_items, &(&1.id == item_id))
    if item do
      new_qty = item.quantity - 1
      if new_qty <= 0 do
        case Shopping.remove_from_cart(item_id) do
          {:ok, _} -> {:noreply, reload_cart(socket)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to remove item")}
        end
      else
        case Shopping.update_cart_item_quantity(item_id, new_qty) do
          {:ok, _} -> {:noreply, reload_cart(socket)}
          {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to update quantity")}
        end
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_cart", _params, socket) do
    Shopping.clear_cart(socket.assigns.cart.id)

    {:noreply,
     socket
     |> reload_cart()
     |> put_flash(:info, "Cart cleared")}
  end

  @impl true
  def handle_event("proceed_to_checkout", _params, socket) do
    if length(socket.assigns.cart_items) > 0 do
      {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/checkout")}
    else
      {:noreply, put_flash(socket, :error, "Your cart is empty")}
    end
  end

  defp get_or_create_cart(socket, session) do
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

  defp reload_cart(socket) do
    cart_items = Shopping.list_cart_items(socket.assigns.cart.id)
    cart_total = Shopping.calculate_cart_total(socket.assigns.cart.id)

    socket
    |> assign(:cart_items, cart_items)
    |> assign(:cart_total, cart_total)
  end

  # Helper function for getting product image
  def get_product_image(product) do
    cond do
      # Use primary image if available
      is_list(product.product_images) and product.product_images != [] ->
        case Enum.find(product.product_images, & &1.is_primary) do
          nil -> product.product_images |> List.first() |> Map.get(:image_url)
          img -> img.image_url
        end

      # Fallback to old image field
      product.image != nil and product.image != "" ->
        product.image

      # Default placeholder
      true ->
        "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop"
    end
  end

  # Use imported HandmadeHubWeb.FormatHelpers.format_price/1 instead of local helper
end
