defmodule HandmadeHub.Payments do
  @moduledoc """
  The Payments context handles all payment-related operations including
  deposits, payouts, and refunds through the pawaPay payment gateway.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo

  alias HandmadeHub.Payments.{PawapayTransaction, ArtisanPayout, PayoutSettings, PawapayClient}
  alias HandmadeHub.Orders

  require Logger

  ## Pawapay Transactions

  @doc """
  Gets a single transaction by transaction_id.
  """
  def get_transaction_by_id(transaction_id) do
    Repo.get_by(PawapayTransaction, transaction_id: transaction_id)
  end

  @doc """
  Lists all transactions with optional filtering.
  """
  def list_transactions(filters \\ %{}) do
    PawapayTransaction
    |> apply_transaction_filters(filters)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
    |> Repo.preload([:order, :payout, :artisan])
  end

  defp apply_transaction_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:type, type}, q when not is_nil(type) ->
        where(q, [t], t.transaction_type == ^type)

      {:status, status}, q when not is_nil(status) ->
        where(q, [t], t.status == ^status)

      {:artisan_id, artisan_id}, q when not is_nil(artisan_id) ->
        where(q, [t], t.artisan_id == ^artisan_id)

      _, q ->
        q
    end)
  end

  @doc """
  Creates a deposit transaction for an order and initiates payment.

  Returns {:ok, redirect_url} if successful, {:error, reason} otherwise.
  """
  def create_deposit(order, payment_params, return_url) do
    deposit_id = Ecto.UUID.generate()

    # Create transaction record
    transaction_attrs = %{
      transaction_id: deposit_id,
      transaction_type: "deposit",
      status: "pending",
      amount: order.total,
      currency: "ZMW",
      order_id: order.id
    }

    with {:ok, _transaction} <- create_transaction(transaction_attrs),
         {:ok, order} <- Orders.update_order(order, %{pawapay_deposit_id: deposit_id}),
         {:ok, redirect_url} <- request_payment_page(order, deposit_id, return_url, payment_params) do
      {:ok, redirect_url}
    else
      {:error, reason} ->
        Logger.error("Failed to create deposit: #{inspect(reason)}")
        {:error, "Failed to initialize payment"}
    end
  end

  defp request_payment_page(order, deposit_id, return_url, payment_params) do
    phone_number =
      payment_params["mobile_money_number"]
      |> normalize_msisdn()

    params = %{
      deposit_id: deposit_id,
      return_url: return_url,
      reason: "Order ##{order.order_number}",
      amount: order.total,
      currency: "ZMW",
      phone_number: phone_number,
      country: "ZMB"
    }

    PawapayClient.create_payment_page(params)
  end

  @doc """
  Processes a deposit callback from pawaPay.
  """
  def process_deposit_callback(callback_data) do
    deposit_id = callback_data["depositId"]
    status = map_pawapay_status(callback_data["status"])

    case get_transaction_by_id(deposit_id) do
      nil ->
        Logger.error("Received callback for unknown deposit: #{deposit_id}")
        {:error, :not_found}

      transaction ->
        update_attrs = %{
          status: status,
          callback_data: callback_data,
          provider_response: Jason.encode!(callback_data)
        }

        case update_transaction(transaction, update_attrs) do
          {:ok, updated_transaction} ->
            if status == "completed" and updated_transaction.order_id do
              Orders.mark_order_as_paid(updated_transaction.order_id, deposit_id)
            end

            {:ok, updated_transaction}

          error ->
            error
        end
    end
  end

  @doc """
  Creates a payout for an artisan.
  """
  def create_payout(artisan_payout) do
    payout_id = Ecto.UUID.generate()

    # Create transaction record
    transaction_attrs = %{
      transaction_id: payout_id,
      transaction_type: "payout",
      status: "pending",
      amount: artisan_payout.net_amount,
      currency: artisan_payout.currency,
      payout_id: artisan_payout.id,
      artisan_id: artisan_payout.artisan_id
    }

    with {:ok, transaction} <- create_transaction(transaction_attrs),
         {:ok, payout_response} <- initiate_payout_request(artisan_payout, payout_id) do
      update_transaction(transaction, %{
        status: "processing",
        provider_response: Jason.encode!(payout_response)
      })

      {:ok, transaction}
    else
      {:error, reason} ->
        Logger.error("Failed to create payout: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp initiate_payout_request(artisan_payout, payout_id) do
    artisan = Repo.preload(artisan_payout, :artisan).artisan

    params = %{
      payout_id: payout_id,
      amount: artisan_payout.net_amount,
      currency: artisan_payout.currency,
      phone_number: artisan.phone,
      correspondent: get_correspondent_from_phone(artisan.phone),
      reason: "Payout for period: #{artisan_payout.payment_period}",
      country: "ZMB"
    }

    PawapayClient.initiate_payout(params)
  end

  defp get_correspondent_from_phone(phone) do
    # Simple logic to determine mobile money provider from phone prefix
    # In Zambia: MTN starts with 096/076, Airtel with 097/077, Zamtel with 095/075
    cond do
      String.starts_with?(phone, "096") or String.starts_with?(phone, "076") or String.starts_with?(phone, "26096") or String.starts_with?(phone, "26076") ->
        "MTN_MOMO_ZMB"

      String.starts_with?(phone, "097") or String.starts_with?(phone, "077") or String.starts_with?(phone, "26097") or String.starts_with?(phone, "26077") ->
        "AIRTEL_OAPI_ZMB"

      String.starts_with?(phone, "095") or String.starts_with?(phone, "075") or String.starts_with?(phone, "26095") or String.starts_with?(phone, "26075") ->
        "ZAMTEL_ZMB"

      true ->
        "MTN_MOMO_ZMB" # Default
    end
  end

  defp normalize_msisdn(nil), do: nil

  defp normalize_msisdn(number) when is_binary(number) do
    digits = String.replace(number, ~r/\D/, "")

    cond do
      String.starts_with?(digits, "260") and String.length(digits) == 12 -> digits
      String.starts_with?(digits, "0") and String.length(digits) == 10 -> "260" <> String.slice(digits, 1, 9)
      true -> digits
    end
  end

  defp normalize_msisdn(_), do: nil

  @doc """
  Processes a payout callback from pawaPay.
  """
  def process_payout_callback(callback_data) do
    payout_id = callback_data["payoutId"]
    status = map_pawapay_status(callback_data["status"])

    case get_transaction_by_id(payout_id) do
      nil ->
        Logger.error("Received callback for unknown payout: #{payout_id}")
        {:error, :not_found}

      transaction ->
        update_attrs = %{
          status: status,
          callback_data: callback_data,
          provider_response: Jason.encode!(callback_data)
        }

        case update_transaction(transaction, update_attrs) do
          {:ok, updated_transaction} ->
            if status == "completed" and updated_transaction.payout_id do
              complete_artisan_payout(updated_transaction.payout_id)
            end

            {:ok, updated_transaction}

          error ->
            error
        end
    end
  end

  @doc """
  Creates a refund for an order.
  """
  def create_refund(order, refund_amount, reason) do
    refund_id = Ecto.UUID.generate()

    unless order.pawapay_deposit_id do
      {:error, "Order does not have a pawaPay deposit ID"}
    else
      # Create transaction record
      transaction_attrs = %{
        transaction_id: refund_id,
        transaction_type: "refund",
        status: "pending",
        amount: refund_amount,
        currency: "ZMW",
        order_id: order.id
      }

      with {:ok, transaction} <- create_transaction(transaction_attrs),
           {:ok, refund_response} <- request_refund(order.pawapay_deposit_id, refund_id, refund_amount, reason) do
        update_transaction(transaction, %{
          status: "processing",
          provider_response: Jason.encode!(refund_response)
        })

        {:ok, transaction}
      else
        {:error, reason} ->
          Logger.error("Failed to create refund: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp request_refund(deposit_id, refund_id, amount, reason) do
    params = %{
      deposit_id: deposit_id,
      refund_id: refund_id,
      amount: amount,
      reason: reason
    }

    PawapayClient.request_refund(params)
  end

  @doc """
  Processes a refund callback from pawaPay.
  """
  def process_refund_callback(callback_data) do
    refund_id = callback_data["refundId"]
    status = map_pawapay_status(callback_data["status"])

    case get_transaction_by_id(refund_id) do
      nil ->
        Logger.error("Received callback for unknown refund: #{refund_id}")
        {:error, :not_found}

      transaction ->
        update_attrs = %{
          status: status,
          callback_data: callback_data,
          provider_response: Jason.encode!(callback_data)
        }

        case update_transaction(transaction, update_attrs) do
          {:ok, updated_transaction} ->
            if status == "completed" and updated_transaction.order_id do
              Orders.update_order_payment_status(updated_transaction.order_id, "refunded")
            end

            {:ok, updated_transaction}

          error ->
            error
        end
    end
  end

  defp create_transaction(attrs) do
    %PawapayTransaction{}
    |> PawapayTransaction.changeset(attrs)
    |> Repo.insert()
  end

  defp update_transaction(%PawapayTransaction{} = transaction, attrs) do
    transaction
    |> PawapayTransaction.changeset(attrs)
    |> Repo.update()
  end

  defp map_pawapay_status(pawapay_status) do
    case pawapay_status do
      "COMPLETED" -> "completed"
      "ACCEPTED" -> "processing"
      "SUBMITTED" -> "processing"
      "FAILED" -> "failed"
      "REJECTED" -> "failed"
      "CANCELLED" -> "cancelled"
      _ -> "pending"
    end
  end

  ## Artisan Payouts

  @doc """
  Lists all payouts with optional filtering.
  """
  def list_payouts(filters \\ %{}) do
    ArtisanPayout
    |> apply_payout_filters(filters)
    |> order_by([p], desc: p.scheduled_date)
    |> Repo.all()
    |> Repo.preload(:artisan)
  end

  defp apply_payout_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:artisan_id, artisan_id}, q when not is_nil(artisan_id) ->
        where(q, [p], p.artisan_id == ^artisan_id)

      {:status, status}, q when not is_nil(status) ->
        where(q, [p], p.status == ^status)

      _, q ->
        q
    end)
  end

  @doc """
  Gets a single payout.
  """
  def get_payout!(id) do
    ArtisanPayout
    |> Repo.get!(id)
    |> Repo.preload([:artisan, :transactions])
  end

  @doc """
  Creates an artisan payout record.
  """
  def create_artisan_payout(attrs) do
    %ArtisanPayout{}
    |> ArtisanPayout.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an artisan payout.
  """
  def update_artisan_payout(%ArtisanPayout{} = payout, attrs) do
    payout
    |> ArtisanPayout.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks an artisan payout as completed.
  """
  def complete_artisan_payout(payout_id) do
    payout = get_payout!(payout_id)

    update_artisan_payout(payout, %{
      status: "completed",
      completed_at: DateTime.utc_now()
    })
  end

  ## Payout Settings

  @doc """
  Gets the current payout settings (creates default if none exist).
  """
  def get_payout_settings do
    case Repo.one(PayoutSettings) do
      nil -> create_default_payout_settings()
      settings -> settings
    end
  end

  @doc """
  Updates payout settings.
  """
  def update_payout_settings(attrs) do
    settings = get_payout_settings()

    settings
    |> PayoutSettings.changeset(attrs)
    |> Repo.update()
  end

  defp create_default_payout_settings do
    {:ok, settings} =
      %PayoutSettings{}
      |> PayoutSettings.changeset(%{
        schedule_type: "weekly",
        schedule_day: 1,
        minimum_payout_amount: Decimal.new("50.00"),
        platform_fee_percentage: Decimal.new("10.00"),
        is_active: true
      })
      |> Repo.insert()

    settings
  end
end
