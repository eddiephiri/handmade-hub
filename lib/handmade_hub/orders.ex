defmodule HandmadeHub.Orders do
  @moduledoc """
  The Orders context handles order processing, payment, and fulfillment.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Orders.{Order, OrderItem, ShippingAddress}
  alias HandmadeHub.Catalog
  alias HandmadeHub.Shopping

  @doc """
  Returns the list of orders.
  """
  def list_orders do
    Repo.all(Order)
    |> Repo.preload([:user, :order_items, :shipping_address])
  end

  @doc """
  Returns the list of orders for a specific user.
  """
  def list_user_orders(user_id) do
    Order
    |> where([o], o.user_id == ^user_id)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
    |> Repo.preload([:order_items, :shipping_address])
  end

  @doc """
  Gets a single order.
  """
  def get_order!(id) do
    Order
    |> Repo.get!(id)
    |> Repo.preload([:user, :order_items, :shipping_address])
  end

  @doc """
  Gets an order by order number.
  """
  def get_order_by_number(order_number) do
    Order
    |> where([o], o.order_number == ^order_number)
    |> Repo.one()
    |> Repo.preload([:user, :order_items, :shipping_address])
  end

  @doc """
  Creates an order from a cart ID.
  """
  def create_order_from_cart_id(cart_id, user, shipping_attrs, payment_attrs) do
    cart_items = Shopping.list_cart_items(cart_id)
    
    result = create_order_from_cart(cart_items, user, shipping_attrs, payment_attrs)
    
    # Convert cart to order if successful
    case result do
      {:ok, order} ->
        Shopping.convert_cart_to_order(cart_id)
        {:ok, order}
      error -> error
    end
  end

  @doc """
  Creates an order from cart items.
  """
  def create_order_from_cart(cart_items, user, shipping_attrs, payment_attrs) do
    Repo.transaction(fn ->
      # Calculate totals
      subtotal = calculate_cart_subtotal(cart_items)
      shipping_fee = calculate_shipping_fee(shipping_attrs)
      total = Order.calculate_total(subtotal, shipping_fee)
      
      # Create order
      order_attrs = %{
        order_number: Order.generate_order_number(),
        user_id: user && user.id,
        customer_email: user && user.email || payment_attrs["customer_email"],
        customer_phone: user && user.phone || payment_attrs["customer_phone"],
        customer_name: user && user.name || payment_attrs["customer_name"],
        subtotal: subtotal,
        shipping_fee: shipping_fee,
        total: total,
        payment_method: payment_attrs["payment_method"],
        mobile_money_provider: payment_attrs["mobile_money_provider"],
        mobile_money_number: payment_attrs["mobile_money_number"],
        status: "pending",
        payment_status: "pending"
      }
      
      case create_order(order_attrs) do
        {:ok, order} ->
          # Create order items
          Enum.each(cart_items, fn item ->
            create_order_item!(order, item)
          end)
          
          # Create shipping address
          create_shipping_address!(order, shipping_attrs)
          
          # Return the complete order
          get_order!(order.id)
          
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp create_order_item!(order, cart_item) do
    product = Catalog.get_product!(cart_item.product_id)
    
    attrs = %{
      order_id: order.id,
      product_id: product.id,
      product_name: product.name,
      product_price: product.price,
      quantity: cart_item.quantity,
      subtotal: OrderItem.calculate_subtotal(product.price, cart_item.quantity)
    }
    
    %OrderItem{}
    |> OrderItem.changeset(attrs)
    |> Repo.insert!()
  end

  defp create_shipping_address!(order, attrs) do
    attrs = Map.put(attrs, "order_id", order.id)
    
    %ShippingAddress{}
    |> ShippingAddress.changeset(attrs)
    |> Repo.insert!()
  end

  defp calculate_cart_subtotal(cart_items) do
    cart_items
    |> Enum.reduce(Decimal.new("0"), fn item, acc ->
      product = Catalog.get_product!(item.product_id)
      item_total = OrderItem.calculate_subtotal(product.price, item.quantity)
      Decimal.add(acc, item_total)
    end)
  end

  defp calculate_shipping_fee(shipping_attrs) do
    # Basic shipping fee calculation based on location
    # This can be made more sophisticated based on business rules
    case shipping_attrs["city"] do
      city when city in ["Lusaka", "Kitwe", "Ndola"] -> Decimal.new("50")
      _ -> Decimal.new("75")
    end
  end

  @doc """
  Creates an order.
  """
  def create_order(attrs \\ %{}) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an order.
  """
  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates order payment status after successful payment.
  """
  def mark_order_as_paid(order_id, payment_reference) do
    order = get_order!(order_id)
    
    update_order(order, %{
      payment_status: "paid",
      payment_reference: payment_reference,
      status: "processing"
    })
  end

  @doc """
  Updates order status.
  """
  def update_order_status(order_id, status) do
    order = get_order!(order_id)
    update_order(order, %{status: status})
  end

  @doc """
  Cancels an order.
  """
  def cancel_order(order_id) do
    order = get_order!(order_id)
    
    if order.status in ["pending", "processing"] do
      update_order(order, %{status: "cancelled"})
    else
      {:error, "Cannot cancel order in current status"}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking order changes.
  """
  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.changeset(order, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking shipping address changes.
  """
  def change_shipping_address(%ShippingAddress{} = address, attrs \\ %{}) do
    ShippingAddress.changeset(address, attrs)
  end

  @doc """
  Gets order statistics for admin dashboard.
  """
  def get_order_stats do
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    
    %{
      total_orders: Repo.aggregate(Order, :count),
      pending_orders: Repo.aggregate(from(o in Order, where: o.status == "pending"), :count),
      processing_orders: Repo.aggregate(from(o in Order, where: o.status == "processing"), :count),
      completed_orders: Repo.aggregate(from(o in Order, where: o.status == "delivered"), :count),
      monthly_revenue: Repo.one(
        from o in Order,
        where: o.payment_status == "paid" and o.inserted_at >= ^start_of_month,
        select: sum(o.total)
      ) || Decimal.new("0")
    }
  end
end
