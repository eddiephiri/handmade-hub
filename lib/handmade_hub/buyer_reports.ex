defmodule HandmadeHub.BuyerReports do
  @moduledoc """
  The BuyerReports context provides report data preparation for buyers.
  """

  alias HandmadeHub.Orders

  @doc """
  Gets order history report data for a buyer.
  """
  def get_order_history_data(buyer_id, filters \\ %{}) do
    orders = Orders.list_user_orders(buyer_id)

    # Apply filters if provided
    orders =
      orders
      |> filter_by_status(filters[:status])
      |> filter_by_date_range(filters[:start_date], filters[:end_date])

    stats = calculate_buyer_stats(orders)

    %{
      orders: orders,
      stats: stats
    }
  end

  @doc """
  Gets purchase summary report data for a buyer.
  """
  def get_purchase_summary_data(buyer_id) do
    orders = Orders.list_user_orders(buyer_id)
    stats = calculate_buyer_stats(orders)

    %{
      orders: orders,
      stats: stats
    }
  end

  # Private helper functions

  defp calculate_buyer_stats(orders) do
    %{
      total_orders: length(orders),
      pending_orders: Enum.count(orders, &(&1.status == "pending")),
      processing_orders: Enum.count(orders, &(&1.status == "processing")),
      delivered_orders: Enum.count(orders, &(&1.status == "delivered")),
      cancelled_orders: Enum.count(orders, &(&1.status == "cancelled")),
      total_spent: calculate_total_spent(orders),
      average_order_value: calculate_average_order_value(orders)
    }
  end

  defp calculate_total_spent(orders) do
    orders
    |> Enum.filter(&(&1.payment_status == "paid"))
    |> Enum.reduce(Decimal.new("0"), fn order, acc ->
      total = order.total || Decimal.new("0")
      Decimal.add(acc, total)
    end)
  end

  defp calculate_average_order_value(orders) do
    paid_orders = Enum.filter(orders, &(&1.payment_status == "paid"))
    total_spent = calculate_total_spent(orders)

    if length(paid_orders) > 0 do
      Decimal.div(total_spent, Decimal.new(length(paid_orders)))
    else
      Decimal.new("0")
    end
  end

  defp filter_by_status(orders, nil), do: orders
  defp filter_by_status(orders, ""), do: orders
  defp filter_by_status(orders, status) do
    Enum.filter(orders, &(&1.status == status))
  end

  defp filter_by_date_range(orders, nil, nil), do: orders
  defp filter_by_date_range(orders, start_date, nil) when not is_nil(start_date) do
    Enum.filter(orders, fn order ->
      DateTime.compare(order.inserted_at, start_date) != :lt
    end)
  end
  defp filter_by_date_range(orders, nil, end_date) when not is_nil(end_date) do
    Enum.filter(orders, fn order ->
      DateTime.compare(order.inserted_at, end_date) != :gt
    end)
  end
  defp filter_by_date_range(orders, start_date, end_date) do
    orders
    |> filter_by_date_range(start_date, nil)
    |> filter_by_date_range(nil, end_date)
  end
end
