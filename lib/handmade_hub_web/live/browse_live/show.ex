defmodule HandmadeHubWeb.BrowseLive.Show do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.Catalog
  alias HandmadeHub.Shopping
  alias HandmadeHub.Reviews

  @impl true
  def mount(%{"id" => id}, session, socket) do
    product = id |> String.to_integer() |> Catalog.get_product!()
    avg = Reviews.average_product_rating(product.id)
    avg_float = ensure_float(avg)
    reviews = Reviews.list_product_reviews(product.id)
    primary = Enum.find(product.product_images || [], &(&1.is_primary)) || List.first(product.product_images || [])
    selected_url = if primary, do: primary.image_url, else: product.image

    guest_session_id = session["guest_session_id"] || Ecto.UUID.generate()

    {:ok,
     assign(socket,
       page_title: product.name,
       product: product,
       rating_average: avg_float,
       product_reviews: reviews,
       review_form: to_form(%{}, as: :review),
       selected_image_url: selected_url,
       guest_session_id: guest_session_id
     )}
  end

  @impl true
  def handle_event("submit_review", %{"review" => %{"rating" => rating, "comment" => comment}}, socket) do
    if socket.assigns[:current_user] do
      {:ok, _} = Reviews.create_product_review(socket.assigns.current_user.id, socket.assigns.product.id, String.to_integer(rating), comment)
      new_avg = Reviews.average_product_rating(socket.assigns.product.id) |> ensure_float()
      {:noreply,
       socket
       |> assign(:rating_average, new_avg)
       |> assign(:product_reviews, Reviews.list_product_reviews(socket.assigns.product.id))
       |> assign(:review_form, to_form(%{}, as: :review))
       |> put_flash(:info, "Thanks for your review!")}
    else
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    end
  end

  defp ensure_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp ensure_float(n) when is_integer(n), do: n * 1.0
  defp ensure_float(n) when is_float(n), do: n

  @impl true
  def handle_event("select_image", %{"url" => url}, socket) do
    {:noreply, assign(socket, :selected_image_url, url)}
  end

  @impl true
  def handle_event("add_to_cart", _params, socket) do
    user = socket.assigns[:current_user]
    session_id = socket.assigns[:guest_session_id]
    {:ok, cart} = Shopping.get_or_create_cart((user && user.id), (user && nil) || session_id)
    case Shopping.add_to_cart(cart.id, socket.assigns.product.id, 1) do
      {:ok, _item} -> {:noreply, put_flash(socket, :info, "Added to cart")}
      {:error, :insufficient_stock} -> {:noreply, put_flash(socket, :error, "Insufficient stock")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not add to cart")}
    end
  end

  @impl true
  def handle_event("buy_now", _params, socket) do
    user = socket.assigns[:current_user]
    if user do
      {:ok, cart} = Shopping.get_or_create_cart(user.id, nil)
      _ = Shopping.clear_cart(cart.id)
      case Shopping.add_to_cart(cart.id, socket.assigns.product.id, 1) do
        {:ok, _} -> {:noreply, push_navigate(socket, to: ~p"/checkout")}
        {:error, :insufficient_stock} -> {:noreply, put_flash(socket, :error, "Insufficient stock")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Could not start checkout")}
      end
    else
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    end
  end
end
