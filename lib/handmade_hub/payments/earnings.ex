defmodule HandmadeHub.Payments.Earnings do
  @moduledoc """
  Module for calculating artisan earnings and managing payout eligibility.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Orders.{Order, OrderItem}
  alias HandmadeHub.Catalog.Product
  alias HandmadeHub.Payments.{ArtisanPayout, PayoutSettings}

  @doc """
  Calculates earnings for an artisan within a date range.

  Returns a map with:
  - gross_amount: Total earnings before fees
  - platform_fee: Amount deducted as platform fee
  - net_amount: Amount artisan will receive
  - order_ids: List of order IDs included
  - transaction_count: Number of orders
  """
  def calculate_artisan_earnings(artisan_id, start_date, end_date) do
    settings = Repo.one(PayoutSettings) || default_settings()

    eligible_orders = get_payout_eligible_orders(artisan_id, start_date, end_date)
    order_ids = Enum.map(eligible_orders, & &1.id)

    gross_amount =
      eligible_orders
      |> Enum.reduce(Decimal.new("0"), fn order, acc ->
        artisan_earnings = calculate_artisan_earnings_from_order(artisan_id, order)
        Decimal.add(acc, artisan_earnings)
      end)

    platform_fee = apply_platform_fee(gross_amount, settings.platform_fee_percentage)
    net_amount = Decimal.sub(gross_amount, platform_fee)

    %{
      gross_amount: gross_amount,
      platform_fee: platform_fee,
      net_amount: net_amount,
      order_ids: order_ids,
      transaction_count: length(order_ids)
    }
  end

  @doc """
  Gets orders that are eligible for payout for a specific artisan.

  Criteria:
  - Order payment_status is "paid"
  - Order contains items from the artisan
  - Order is within the specified date range
  - Order has not been included in a previous completed payout
  """
  def get_payout_eligible_orders(artisan_id, start_date, end_date) do
    # Get IDs of orders already included in completed payouts
    previously_paid_order_ids = get_previously_paid_order_ids(artisan_id)

    from(o in Order,
      join: oi in OrderItem, on: oi.order_id == o.id,
      join: p in Product, on: p.id == oi.product_id,
      where: p.artisan_id == ^artisan_id,
      where: o.payment_status == "paid",
      where: o.inserted_at >= ^start_date,
      where: o.inserted_at <= ^end_date,
      where: o.id not in ^previously_paid_order_ids,
      distinct: true,
      preload: [order_items: :product]
    )
    |> Repo.all()
  end

  @doc """
  Gets pending earnings for an artisan (earnings not yet paid out).
  """
  def get_artisan_pending_earnings(artisan_id) do
    # Get the last completed payout date, or use account creation date
    last_payout_date = get_last_payout_date(artisan_id)
    now = DateTime.utc_now()

    calculate_artisan_earnings(artisan_id, last_payout_date, now)
  end

  @doc """
  Applies platform fee to an amount.

  ## Parameters
    - amount: Gross amount as Decimal
    - fee_percentage: Platform fee percentage as Decimal

  ## Returns
    - Fee amount as Decimal
  """
  def apply_platform_fee(amount, fee_percentage) do
    amount
    |> Decimal.mult(fee_percentage)
    |> Decimal.div(100)
    |> Decimal.round(2)
  end

  @doc """
  Checks if an artisan has earnings that meet the minimum payout threshold.
  """
  def meets_minimum_payout?(artisan_id) do
    settings = Repo.one(PayoutSettings) || default_settings()
    pending_earnings = get_artisan_pending_earnings(artisan_id)

    Decimal.compare(pending_earnings.net_amount, settings.minimum_payout_amount) != :lt
  end

  # Private functions

  defp calculate_artisan_earnings_from_order(artisan_id, order) do
    order.order_items
    |> Enum.filter(fn item -> item.product.artisan_id == artisan_id end)
    |> Enum.reduce(Decimal.new("0"), fn item, acc ->
      Decimal.add(acc, item.subtotal)
    end)
  end

  defp get_previously_paid_order_ids(artisan_id) do
    from(p in ArtisanPayout,
      where: p.artisan_id == ^artisan_id,
      where: p.status == "completed",
      select: p.order_ids
    )
    |> Repo.all()
    |> List.flatten()
    |> Enum.uniq()
  end

  defp get_last_payout_date(artisan_id) do
    case Repo.one(
           from p in ArtisanPayout,
             where: p.artisan_id == ^artisan_id,
             where: p.status == "completed",
             order_by: [desc: p.completed_at],
             limit: 1,
             select: p.completed_at
         ) do
      nil ->
        # No previous payouts, use 90 days ago as default
        DateTime.utc_now() |> DateTime.add(-90, :day)

      date ->
        date
    end
  end

  defp default_settings do
    %PayoutSettings{
      schedule_type: "weekly",
      schedule_day: 1,
      minimum_payout_amount: Decimal.new("50.00"),
      platform_fee_percentage: Decimal.new("10.00"),
      is_active: true
    }
  end
end
