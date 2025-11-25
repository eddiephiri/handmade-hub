defmodule HandmadeHub.Reports do
  @moduledoc """
  The Reports context provides centralized report data preparation.
  This module is format-agnostic and focuses on data aggregation.
  """

  alias HandmadeHub.{Orders, Accounts, Catalog, Payments}
  alias HandmadeHub.Repo
  import Ecto.Query

  @doc """
  Gets platform-wide order statistics for admin reports.
  """
  def get_platform_order_stats(filters \\ %{}) do
    base_query = from(o in Orders.Order)

    query =
      base_query
      |> apply_order_filters(filters)

    %{
      total_orders: Repo.aggregate(query, :count),
      total_revenue: get_total_revenue(query),
      pending_orders: get_orders_by_status(query, "pending"),
      processing_orders: get_orders_by_status(query, "processing"),
      completed_orders: get_orders_by_status(query, "delivered"),
      cancelled_orders: get_orders_by_status(query, "cancelled"),
      monthly_series: Orders.orders_monthly_series(12)
    }
  end

  @doc """
  Gets platform user statistics for admin reports.
  """
  def get_platform_user_stats(filters \\ %{}) do
    %{
      total_users: Accounts.count_users(),
      total_artisans: Accounts.count_artisans(),
      total_buyers: Accounts.count_buyers(),
      pending_artisans: get_pending_artisans_count(),
      active_artisans: get_active_artisans_count()
    }
  end

  @doc """
  Gets platform product statistics for admin reports.
  """
  def get_platform_product_stats(filters \\ %{}) do
    %{
      total_products: Catalog.count_products(),
      pending_products: get_pending_products_count(),
      active_products: get_active_products_count()
    }
  end

  @doc """
  Gets financial statistics for admin reports.
  """
  def get_financial_stats(filters \\ %{}) do
    %{
      total_transactions: get_total_transactions(),
      completed_transactions: get_completed_transactions(),
      pending_payouts: get_pending_payouts_count(),
      total_payout_amount: get_total_payout_amount(),
      monthly_revenue: get_monthly_revenue()
    }
  end

  @doc """
  Gets detailed order list for reports.
  """
  def get_orders_for_report(filters \\ %{}) do
    Orders.list_orders_admin(filters)
  end

  # Private helper functions

  defp apply_order_filters(query, filters) do
    query
    |> filter_by_date_range(filters[:start_date], filters[:end_date])
    |> filter_by_status(filters[:status])
    |> filter_by_payment_status(filters[:payment_status])
  end

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, start_date, nil) when not is_nil(start_date) do
    from(o in query, where: o.inserted_at >= ^start_date)
  end
  defp filter_by_date_range(query, nil, end_date) when not is_nil(end_date) do
    from(o in query, where: o.inserted_at <= ^end_date)
  end
  defp filter_by_date_range(query, start_date, end_date) do
    from(o in query, where: o.inserted_at >= ^start_date and o.inserted_at <= ^end_date)
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, ""), do: query
  defp filter_by_status(query, status) do
    from(o in query, where: o.status == ^status)
  end

  defp filter_by_payment_status(query, nil), do: query
  defp filter_by_payment_status(query, ""), do: query
  defp filter_by_payment_status(query, payment_status) do
    from(o in query, where: o.payment_status == ^payment_status)
  end

  defp get_total_revenue(query) do
    from(o in query,
      where: o.payment_status == "paid",
      select: sum(o.total)
    )
    |> Repo.one() || Decimal.new("0")
  end

  defp get_orders_by_status(query, status) do
    from(o in query,
      where: o.status == ^status,
      select: count(o.id)
    )
    |> Repo.one() || 0
  end

  defp get_pending_artisans_count do
    from(u in Accounts.User,
      where: u.role == "artisan" and u.artisan_status == "pending"
    )
    |> Repo.aggregate(:count)
  end

  defp get_active_artisans_count do
    from(u in Accounts.User,
      where: u.role == "artisan" and u.artisan_status == "approved"
    )
    |> Repo.aggregate(:count)
  end

  defp get_pending_products_count do
    from(p in Catalog.Product,
      where: is_nil(p.removed_at) and p.approval_status == "pending"
    )
    |> Repo.aggregate(:count)
  end

  defp get_active_products_count do
    from(p in Catalog.Product,
      where: is_nil(p.removed_at) and p.approval_status == "approved"
    )
    |> Repo.aggregate(:count)
  end

  defp get_total_transactions do
    Repo.aggregate(Payments.PawapayTransaction, :count)
  end

  defp get_completed_transactions do
    from(t in Payments.PawapayTransaction,
      where: t.status == "completed"
    )
    |> Repo.aggregate(:count)
  end

  defp get_pending_payouts_count do
    from(p in Payments.ArtisanPayout,
      where: p.status in ["pending", "processing"]
    )
    |> Repo.aggregate(:count)
  end

  defp get_total_payout_amount do
    from(p in Payments.ArtisanPayout,
      where: p.status == "completed",
      select: sum(p.net_amount)
    )
    |> Repo.one() || Decimal.new("0")
  end

  defp get_monthly_revenue do
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    start_datetime = DateTime.new!(start_of_month, ~T[00:00:00], "Etc/UTC")

    from(o in Orders.Order,
      where: o.payment_status == "paid" and o.inserted_at >= ^start_datetime,
      select: sum(o.total)
    )
    |> Repo.one() || Decimal.new("0")
  end
end
