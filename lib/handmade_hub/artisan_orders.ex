defmodule HandmadeHub.ArtisanOrders do
  @moduledoc """
  The ArtisanOrders context handles order management for artisans.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Orders.{Order, OrderItem}
  alias HandmadeHub.Catalog.Product

  @doc """
  Returns the list of orders for products belonging to an artisan.
  """
  def list_artisan_orders(artisan_id, filters \\ %{}) do
    base_query =
      from o in Order,
        join: oi in OrderItem, on: oi.order_id == o.id,
        join: p in Product, on: p.id == oi.product_id,
        where: p.artisan_id == ^artisan_id,
        distinct: true,
        order_by: [desc: o.inserted_at],
        preload: [:user, :shipping_address, order_items: [:product]]

    base_query
    |> apply_filters(filters)
    |> Repo.all()
  end

  @doc """
  Gets a single order with items for an artisan.
  """
  def get_artisan_order!(artisan_id, order_id) do
    from(o in Order,
      join: oi in OrderItem, on: oi.order_id == o.id,
      join: p in Product, on: p.id == oi.product_id,
      where: p.artisan_id == ^artisan_id and o.id == ^order_id,
      distinct: true,
      preload: [:user, :shipping_address, order_items: [:product]]
    )
    |> Repo.one!()
  end

  @doc """
  Gets order items for an artisan from a specific order.
  """
  def get_artisan_order_items(artisan_id, order_id) do
    from(oi in OrderItem,
      join: p in Product, on: p.id == oi.product_id,
      where: p.artisan_id == ^artisan_id and oi.order_id == ^order_id,
      preload: [:product]
    )
    |> Repo.all()
  end

  @doc """
  Gets statistics for an artisan's orders.
  """
  def get_artisan_stats(artisan_id, date_range \\ :all_time) do
    {start_date, end_date} = get_date_range(date_range)

    # Base query for artisan's order items
    base_query =
      from oi in OrderItem,
        join: p in Product, on: p.id == oi.product_id,
        join: o in Order, on: o.id == oi.order_id,
        where: p.artisan_id == ^artisan_id

    # Add date filtering if needed
    date_filtered_query =
      if start_date do
        from [oi, p, o] in base_query,
          where: o.inserted_at >= ^start_date and o.inserted_at <= ^end_date
      else
        base_query
      end

    # Total orders (distinct)
    total_orders =
      from([oi, p, o] in date_filtered_query,
        select: count(o.id, :distinct)
      )
      |> Repo.one() || 0

    # Revenue calculation
    revenue_query =
      from [oi, p, o] in date_filtered_query,
        where: o.payment_status == "paid",
        select: sum(oi.subtotal)

    total_revenue = Repo.one(revenue_query) || Decimal.new("0")

    # Pending orders
    pending_orders =
      from([oi, p, o] in date_filtered_query,
        where: o.status == "pending",
        select: count(o.id, :distinct)
      )
      |> Repo.one() || 0

    # Processing orders
    processing_orders =
      from([oi, p, o] in date_filtered_query,
        where: o.status == "processing",
        select: count(o.id, :distinct)
      )
      |> Repo.one() || 0

    # Completed orders
    completed_orders =
      from([oi, p, o] in date_filtered_query,
        where: o.status == "delivered",
        select: count(o.id, :distinct)
      )
      |> Repo.one() || 0

    # Total items sold
    items_sold =
      from([oi, p, o] in date_filtered_query,
        where: o.payment_status == "paid",
        select: sum(oi.quantity)
      )
      |> Repo.one() || 0

    # Best selling products
    best_sellers =
      from([oi, p, o] in date_filtered_query,
        where: o.payment_status == "paid",
        group_by: [p.id, p.name],
        select: %{
          product_id: p.id,
          product_name: p.name,
          quantity_sold: sum(oi.quantity),
          revenue: sum(oi.subtotal)
        },
        order_by: [desc: sum(oi.quantity)],
        limit: 5
      )
      |> Repo.all()

    # Monthly revenue trend (last 6 months)
    monthly_trend = get_monthly_revenue_trend(artisan_id)

    %{
      total_orders: total_orders,
      total_revenue: total_revenue,
      pending_orders: pending_orders,
      processing_orders: processing_orders,
      completed_orders: completed_orders,
      items_sold: items_sold,
      best_sellers: best_sellers,
      monthly_trend: monthly_trend,
      date_range: date_range
    }
  end

  @doc """
  Gets revenue statistics by time period.
  """
  def get_revenue_by_period(artisan_id, period \\ :monthly) do
    query =
      from oi in OrderItem,
        join: p in Product, on: p.id == oi.product_id,
        join: o in Order, on: o.id == oi.order_id,
        where: p.artisan_id == ^artisan_id and o.payment_status == "paid"

    case period do
      :daily ->
        from([oi, p, o] in query,
          group_by: fragment("DATE(?)", o.inserted_at),
          select: %{
            date: fragment("DATE(?)", o.inserted_at),
            revenue: sum(oi.subtotal),
            orders: count(o.id, :distinct)
          },
          order_by: [desc: fragment("DATE(?)", o.inserted_at)],
          limit: 30
        )

      :weekly ->
        from([oi, p, o] in query,
          group_by: [fragment("EXTRACT(YEAR FROM ?)", o.inserted_at), fragment("EXTRACT(WEEK FROM ?)", o.inserted_at)],
          select: %{
            year: fragment("EXTRACT(YEAR FROM ?)", o.inserted_at),
            week: fragment("EXTRACT(WEEK FROM ?)", o.inserted_at),
            revenue: sum(oi.subtotal),
            orders: count(o.id, :distinct)
          },
          order_by: [desc: fragment("EXTRACT(YEAR FROM ?)", o.inserted_at), desc: fragment("EXTRACT(WEEK FROM ?)", o.inserted_at)],
          limit: 12
        )

      :monthly ->
        from([oi, p, o] in query,
          group_by: [fragment("EXTRACT(YEAR FROM ?)", o.inserted_at), fragment("EXTRACT(MONTH FROM ?)", o.inserted_at)],
          select: %{
            year: fragment("EXTRACT(YEAR FROM ?)", o.inserted_at),
            month: fragment("EXTRACT(MONTH FROM ?)", o.inserted_at),
            revenue: sum(oi.subtotal),
            orders: count(o.id, :distinct)
          },
          order_by: [desc: fragment("EXTRACT(YEAR FROM ?)", o.inserted_at), desc: fragment("EXTRACT(MONTH FROM ?)", o.inserted_at)],
          limit: 12
        )
    end
    |> Repo.all()
  end

  @doc """
  Updates the status of an order (only for items belonging to the artisan).
  """
  def update_artisan_order_status(artisan_id, order_id, status) do
    # Verify the artisan has items in this order
    artisan_items = get_artisan_order_items(artisan_id, order_id)

    if Enum.empty?(artisan_items) do
      {:error, "You don't have any items in this order"}
    else
      order = Repo.get!(Order, order_id)

      # Update the status based on business logic
      # For simplicity, we'll update the entire order status
      # In a real marketplace, you might track individual item statuses
      order
      |> Order.changeset(%{status: status})
      |> Repo.update()
    end
  end

  # Private functions

  defp apply_filters(query, filters) do
    query
    |> filter_by_status(filters[:status])
    |> filter_by_payment_status(filters[:payment_status])
    |> filter_by_date_range(filters[:start_date], filters[:end_date])
    |> filter_by_search(filters[:search])
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status) do
    from o in query, where: o.status == ^status
  end

  defp filter_by_payment_status(query, nil), do: query
  defp filter_by_payment_status(query, payment_status) do
    from o in query, where: o.payment_status == ^payment_status
  end

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, start_date, end_date) do
    query = if start_date, do: from(o in query, where: o.inserted_at >= ^start_date), else: query
    if end_date, do: from(o in query, where: o.inserted_at <= ^end_date), else: query
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    from o in query,
      where: ilike(o.order_number, ^search_pattern) or
             ilike(o.customer_name, ^search_pattern) or
             ilike(o.customer_email, ^search_pattern)
  end

  defp get_date_range(:today) do
    today = Date.utc_today()
    start_time = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    end_time = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")
    {start_time, end_time}
  end

  defp get_date_range(:this_week) do
    today = Date.utc_today()
    start_of_week = Date.beginning_of_week(today, :monday)
    start_time = DateTime.new!(start_of_week, ~T[00:00:00], "Etc/UTC")
    end_time = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")
    {start_time, end_time}
  end

  defp get_date_range(:this_month) do
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    start_time = DateTime.new!(start_of_month, ~T[00:00:00], "Etc/UTC")
    end_time = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")
    {start_time, end_time}
  end

  defp get_date_range(:last_30_days) do
    today = Date.utc_today()
    start_date = Date.add(today, -30)
    start_time = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_time = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")
    {start_time, end_time}
  end

  defp get_date_range(:this_year) do
    today = Date.utc_today()
    start_of_year = Date.new!(today.year, 1, 1)
    start_time = DateTime.new!(start_of_year, ~T[00:00:00], "Etc/UTC")
    end_time = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")
    {start_time, end_time}
  end

  defp get_date_range(_), do: {nil, nil}

  defp get_monthly_revenue_trend(artisan_id) do
    six_months_ago = Date.utc_today() |> Date.add(-180)
    six_months_ago_datetime = DateTime.new!(six_months_ago, ~T[00:00:00], "Etc/UTC")

    from(oi in OrderItem,
      join: p in Product, on: p.id == oi.product_id,
      join: o in Order, on: o.id == oi.order_id,
      where: p.artisan_id == ^artisan_id and
             o.payment_status == "paid" and
             o.inserted_at >= ^six_months_ago_datetime,
      group_by: [fragment("EXTRACT(YEAR FROM ?)", o.inserted_at), fragment("EXTRACT(MONTH FROM ?)", o.inserted_at)],
      select: %{
        year: fragment("EXTRACT(YEAR FROM ?)", o.inserted_at),
        month: fragment("EXTRACT(MONTH FROM ?)", o.inserted_at),
        revenue: sum(oi.subtotal)
      },
      order_by: [fragment("EXTRACT(YEAR FROM ?)", o.inserted_at), fragment("EXTRACT(MONTH FROM ?)", o.inserted_at)]
    )
    |> Repo.all()
    |> Enum.map(fn %{year: year, month: month, revenue: revenue} ->
      month_int = to_integer(month)
      year_int = to_integer(year)
      month_name = get_month_name(month_int)
      %{label: "#{month_name} #{year_int}", value: revenue}
    end)
  end

  defp get_month_name(month) do
    ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    |> Enum.at(month - 1)
  end

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_float(value), do: trunc(value)

  defp to_integer(%Decimal{} = value) do
    value
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end
end
