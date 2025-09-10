defmodule HandmadeHub.Orders do
  @moduledoc """
  The Orders context handles order processing, payment, and fulfillment.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Orders.{Order, OrderItem, ShippingAddress, Dispute}
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
  Returns the list of orders with optional admin filters.

  Options:
  - :search (order_number, customer_email, user email/name)
  - :status (order status)
  - :payment_status (payment status)
  """
  def list_orders_admin(opts \\ %{}) do
    search = Map.get(opts, :search)
    status = Map.get(opts, :status)
    payment_status = Map.get(opts, :payment_status)

    Order
    |> then(fn q -> if status && status != "", do: where(q, [o], o.status == ^status), else: q end)
    |> then(fn q -> if payment_status && payment_status != "", do: where(q, [o], o.payment_status == ^payment_status), else: q end)
    |> then(fn q ->
      if search && String.trim(search) != "" do
        like = "%#{search}%"
        from o in q,
          left_join: u in assoc(o, :user),
          where:
            ilike(o.order_number, ^like) or
            ilike(o.customer_email, ^like) or
            ilike(u.email, ^like) or
            ilike(u.name, ^like)
      else
        q
      end
    end)
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
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
      shipping_fee = calculate_delivery_fee(shipping_attrs)
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

  defp calculate_delivery_fee(shipping_attrs) do
    # Flat delivery fees for Lusaka-based delivery. Different cities fallback to higher fee.
    case shipping_attrs["city"] do
      "Lusaka" -> Decimal.new("30")
      city when city in ["Makeni", "Woodlands", "Northmead", "Kabulonga", "Chalala", "Kanyama", "Chilenje", "Roma", "Rhodespark", "Bauleni", "Chelston", "Garden", "Matero", "Kabulonga"] -> Decimal.new("30")
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
  Updates order payment status.
  """
  def update_order_payment_status(order_id, payment_status) do
    order = get_order!(order_id)
    update_order(order, %{payment_status: payment_status})
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
  Refunds an order: sets payment_status to "refunded". Optionally cancels if still pending/processing.
  """
  def refund_order(order_id) do
    order = get_order!(order_id)
    attrs = %{payment_status: "refunded"}
    attrs = if order.status in ["pending", "processing"], do: Map.put(attrs, :status, "cancelled"), else: attrs
    update_order(order, attrs)
  end

  ## Disputes
  def open_dispute(order_id, opened_by_user_id, reason, notes \\ nil) do
    %Dispute{}
    |> Dispute.changeset(%{order_id: order_id, opened_by_user_id: opened_by_user_id, status: "open", reason: reason, notes: notes})
    |> Repo.insert()
  end

  def list_disputes(opts \\ []) do
    status = Keyword.get(opts, :status)
    query = Dispute
    query = if status, do: where(query, [d], d.status == ^status), else: query
    Repo.all(query) |> Repo.preload([:order, :opened_by_user])
  end

  def update_dispute_status(dispute_id, status) when status in ["open", "resolved", "closed"] do
    dispute = Repo.get!(Dispute, dispute_id)
    dispute |> Dispute.changeset(%{status: status}) |> Repo.update()
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
    start_of_month_date = Date.beginning_of_month(today)
    start_of_month = start_of_month_date |> NaiveDateTime.new!(~T[00:00:00]) |> DateTime.from_naive!("Etc/UTC")

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

  @doc """
  Returns monthly order counts and revenue for the last `months_back` months (inclusive of current month).
  """
  def orders_monthly_series(months_back \\ 12) when is_integer(months_back) and months_back > 0 do
    # Determine start date
    today = Date.utc_today()
    start_date = today |> Date.beginning_of_month() |> Date.add(-31 * (months_back - 1))

    start_ndt = NaiveDateTime.new!(start_date, ~T[00:00:00])
    start_dt = DateTime.from_naive!(start_ndt, "Etc/UTC")

    Repo.all(
      from o in Order,
        where: o.inserted_at >= ^start_dt,
        group_by: fragment("date_trunc('month', ?)", o.inserted_at),
        order_by: fragment("date_trunc('month', ?)", o.inserted_at),
        select: %{
          period: fragment("to_char(date_trunc('month', ?), 'YYYY-MM')", o.inserted_at),
          count: count(o.id),
          revenue: coalesce(sum(o.total), 0)
        }
    )
  end
end
