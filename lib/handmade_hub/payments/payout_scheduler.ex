defmodule HandmadeHub.Payments.PayoutScheduler do
  @moduledoc """
  Handles scheduled automatic payouts to artisans.
  """

  require Logger

  alias HandmadeHub.Repo
  alias HandmadeHub.Accounts.User
  alias HandmadeHub.Payments
  alias HandmadeHub.Payments.{PayoutSettings, Earnings}

  import Ecto.Query, warn: false

  @doc """
  Main entry point for scheduled payout processing.
  This is called by the Quantum scheduler.
  """
  def process_scheduled_payouts do
    Logger.info("Starting scheduled payout processing")

    settings = Payments.get_payout_settings()

    unless settings.is_active do
      Logger.info("Payout processing is disabled in settings")
      :ok
    else
      if should_process_payouts_today?(settings) do
        artisans = get_artisans_due_for_payout(settings)
        Logger.info("Processing payouts for #{length(artisans)} artisans")

        results =
          Enum.map(artisans, fn artisan ->
            process_artisan_payout(artisan, settings)
          end)

        successful = Enum.count(results, &match?({:ok, _}, &1))
        failed = Enum.count(results, &match?({:error, _}, &1))

        Logger.info("Payout processing complete: #{successful} successful, #{failed} failed")
        {:ok, %{successful: successful, failed: failed}}
      else
        Logger.info("Today is not a scheduled payout day")
        :ok
      end
    end
  end

  @doc """
  Processes a payout for a specific artisan (manual trigger).
  """
  def process_manual_payout(artisan_id) do
    settings = Payments.get_payout_settings()
    artisan = Repo.get!(User, artisan_id)

    process_artisan_payout(artisan, settings)
  end

  @doc """
  Gets list of artisans who are due for payout based on settings.
  """
  def get_artisans_due_for_payout(settings, opts \\ []) do
    meets_minimum_fun = Keyword.get(opts, :meets_minimum_fun, &Earnings.meets_minimum_payout?/1)

    from(u in User,
      where: u.role == "artisan",
      where: u.artisan_status == "approved"
    )
    |> Repo.all()
    |> Enum.filter(fn artisan ->
      meets_minimum_fun.(artisan.id)
    end)
  end

  # Private functions

  defp should_process_payouts_today?(settings) do
    today = Date.utc_today()
    day_of_week = Date.day_of_week(today) # 1 = Monday, 7 = Sunday
    day_of_month = today.day

    case settings.schedule_type do
      "weekly" ->
        day_of_week == settings.schedule_day

      "monthly" ->
        # Handle months with fewer than 31 days
        if settings.schedule_day > Date.days_in_month(today) do
          day_of_month == Date.days_in_month(today)
        else
          day_of_month == settings.schedule_day
        end

      _ ->
        false
    end
  end

  defp process_artisan_payout(artisan, settings) do
    {start_date, end_date} = get_payout_period(settings)

    earnings = Earnings.calculate_artisan_earnings(artisan.id, start_date, end_date)

    if Decimal.compare(earnings.net_amount, settings.minimum_payout_amount) == :lt do
      Logger.info("Artisan #{artisan.id} earnings (#{earnings.net_amount}) below minimum (#{settings.minimum_payout_amount})")
      {:error, :below_minimum}
    else
      create_payout_batch(artisan, earnings, start_date, end_date)
    end
  end

  defp create_payout_batch(artisan, earnings, start_date, end_date) do
    period_string = format_period(start_date, end_date)

    payout_attrs = %{
      artisan_id: artisan.id,
      amount: earnings.gross_amount,
      currency: "ZMW",
      status: "pending",
      scheduled_date: DateTime.utc_now(),
      payment_period: period_string,
      order_ids: earnings.order_ids,
      transaction_count: earnings.transaction_count,
      platform_fee: earnings.platform_fee,
      net_amount: earnings.net_amount
    }

    case Payments.create_artisan_payout(payout_attrs) do
      {:ok, payout} ->
        Logger.info("Created payout #{payout.id} for artisan #{artisan.id}: #{earnings.net_amount} ZMW")

        # Update payout status to processing
        Payments.update_artisan_payout(payout, %{status: "processing"})

        # Initiate the actual payout via pawaPay
        case Payments.create_payout(payout) do
          {:ok, _transaction} ->
            Logger.info("Successfully initiated payout #{payout.id}")
            {:ok, payout}

          {:error, reason} ->
            Logger.error("Failed to initiate payout #{payout.id}: #{inspect(reason)}")
            Payments.update_artisan_payout(payout, %{
              status: "failed",
              notes: "Failed to initiate: #{inspect(reason)}"
            })

            {:error, reason}
        end

      {:error, changeset} ->
        Logger.error("Failed to create payout record for artisan #{artisan.id}: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  defp get_payout_period(settings) do
    today = DateTime.utc_now()

    case settings.schedule_type do
      "weekly" ->
        # Last 7 days
        start_date = DateTime.add(today, -7, :day)
        {start_date, today}

      "monthly" ->
        # Last 30 days (approximately one month)
        start_date = DateTime.add(today, -30, :day)
        {start_date, today}

      _ ->
        # Default to weekly
        start_date = DateTime.add(today, -7, :day)
        {start_date, today}
    end
  end

  defp format_period(start_date, end_date) do
    start_str = Calendar.strftime(start_date, "%Y-%m-%d")
    end_str = Calendar.strftime(end_date, "%Y-%m-%d")
    "#{start_str} to #{end_str}"
  end
end
