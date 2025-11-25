defmodule HandmadeHub.ArtisanReports do
  @moduledoc """
  The ArtisanReports context provides report data preparation for artisans.
  """

  alias HandmadeHub.{ArtisanOrders, Catalog, Reviews}
  alias HandmadeHub.Repo
  import Ecto.Query

  @doc """
  Gets sales report data for an artisan.
  """
  def get_sales_report_data(artisan_id, date_range \\ :all_time) do
    stats = ArtisanOrders.get_artisan_stats(artisan_id, date_range)
    orders = ArtisanOrders.list_artisan_orders(artisan_id, %{})

    %{
      stats: stats,
      orders: orders,
      date_range: date_range
    }
  end

  @doc """
  Gets product performance report data for an artisan.
  """
  def get_product_performance_data(artisan_id, date_range \\ :all_time) do
    products = Catalog.list_user_products(artisan_id)

    products_with_stats =
      Enum.map(products, fn product ->
        %{
          product: product,
          total_sold: get_product_total_sold(product.id),
          total_revenue: get_product_total_revenue(product.id),
          average_rating: Reviews.average_product_rating(product.id),
          review_count: get_product_review_count(product.id)
        }
      end)
      |> Enum.sort_by(& &1.total_sold, :desc)

    %{
      products: products_with_stats,
      date_range: date_range
    }
  end

  @doc """
  Gets revenue analysis report data for an artisan.
  """
  def get_revenue_analysis_data(artisan_id, date_range \\ :all_time) do
    stats = ArtisanOrders.get_artisan_stats(artisan_id, date_range)
    monthly_trend = ArtisanOrders.get_revenue_by_period(artisan_id, :monthly)

    %{
      stats: stats,
      monthly_trend: monthly_trend,
      date_range: date_range
    }
  end

  # Private helper functions

  defp get_product_total_sold(product_id) do
    from(oi in HandmadeHub.Orders.OrderItem,
      join: o in HandmadeHub.Orders.Order, on: o.id == oi.order_id,
      where: oi.product_id == ^product_id and o.payment_status == "paid",
      select: sum(oi.quantity)
    )
    |> Repo.one() || 0
  end

  defp get_product_total_revenue(product_id) do
    from(oi in HandmadeHub.Orders.OrderItem,
      join: o in HandmadeHub.Orders.Order, on: o.id == oi.order_id,
      where: oi.product_id == ^product_id and o.payment_status == "paid",
      select: sum(oi.subtotal)
    )
    |> Repo.one() || Decimal.new("0")
  end

  defp get_product_review_count(product_id) do
    from(r in HandmadeHub.Reviews.Review,
      where: r.product_id == ^product_id,
      select: count(r.id)
    )
    |> Repo.one() || 0
  end
end
