defmodule HandmadeHub.Payments.PawapayClient do
  @moduledoc """
  HTTP client for interacting with the pawaPay API.
  """

  require Logger

  @doc """
  Creates a payment page for a deposit.

  ## Parameters
    - params: Map with:
      - deposit_id: UUID for the transaction
      - return_url: URL where customer returns after payment
      - reason: Payment description
      - amount: Payment amount
      - currency: Currency code (default: ZMW)
      - phone_number: Customer phone number (optional)
      - country: Country code (default: ZMB)

  ## Returns
    - {:ok, redirect_url} on success
    - {:error, reason} on failure
  """
  def create_payment_page(params) do
    body = %{
      depositId: params.deposit_id,
      returnUrl: params.return_url,
      reason: params.reason,
      amountDetails: %{
        amount: to_string(params.amount),
        currency: params[:currency] || "ZMW"
      }
    }

    body =
      body
      |> maybe_add_field(:phoneNumber, params[:phone_number])
      |> maybe_add_field(:country, params[:country] || "ZMB")

    case post("/v2/paymentpage", body) do
      {:ok, %{"redirectUrl" => redirect_url}} ->
        {:ok, redirect_url}

      {:ok, response} ->
        Logger.error("Unexpected pawaPay response: #{inspect(response)}")
        {:error, "Unexpected response from payment provider"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Initiates a payout to an artisan.

  ## Parameters
    - params: Map with:
      - payout_id: UUID for the payout transaction
      - amount: Payout amount
      - currency: Currency code (default: ZMW)
      - phone_number: Artisan's phone number
      - country: Country code (default: ZMB)
      - reason: Payout description

  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def initiate_payout(params) do
    body = %{
      payoutId: params.payout_id,
      amount: to_string(params.amount),
      currency: params[:currency] || "ZMW",
      correspondent: params.correspondent,
      recipient: %{
        type: "MSISDN",
        address: %{
          value: params.phone_number
        }
      },
      customerTimestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      statementDescription: params.reason,
      country: params[:country] || "ZMB"
    }

    post("/v2/payouts", body)
  end

  @doc """
  Requests a refund for a deposit.

  ## Parameters
    - params: Map with:
      - deposit_id: Original deposit UUID
      - refund_id: UUID for the refund transaction
      - amount: Refund amount
      - reason: Refund reason

  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def request_refund(params) do
    deposit_id = params.deposit_id

    body = %{
      refundId: params.refund_id,
      amount: to_string(params.amount),
      reason: params.reason
    }

    post("/v2/refunds/#{deposit_id}/refund", body)
  end

  @doc """
  Gets the status of a deposit.

  ## Parameters
    - deposit_id: UUID of the deposit

  ## Returns
    - {:ok, deposit_data} on success
    - {:error, reason} on failure
  """
  def get_deposit_status(deposit_id) do
    get("/v2/deposits/#{deposit_id}")
  end

  @doc """
  Gets the status of a payout.

  ## Parameters
    - payout_id: UUID of the payout

  ## Returns
    - {:ok, payout_data} on success
    - {:error, reason} on failure
  """
  def get_payout_status(payout_id) do
    get("/v2/payouts/#{payout_id}")
  end

  # Private functions

  defp post(path, body) do
    url = base_url() <> path
    headers = build_headers()

    case Jason.encode(body) do
      {:ok, json_body} ->
        Logger.info("pawaPay API POST #{path}: #{json_body}")

        case Finch.build(:post, url, headers, json_body)
             |> Finch.request(HandmadeHub.Finch) do
          {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
            case Jason.decode(resp_body) do
              {:ok, data} ->
                Logger.info("pawaPay API success: #{inspect(data)}")
                {:ok, data}

              {:error, _} ->
                Logger.error("pawaPay API invalid JSON response: #{resp_body}")
                {:error, "Invalid response from payment provider"}
            end

          {:ok, %Finch.Response{status: status, body: resp_body}} ->
            Logger.error("pawaPay API error #{status}: #{resp_body}")

            case Jason.decode(resp_body) do
              {:ok, %{"message" => message}} ->
                {:error, "Payment provider error: #{message}"}
              _ ->
                {:error, "Payment provider error (#{status})"}
            end

          {:error, reason} ->
            Logger.error("pawaPay API request failed: #{inspect(reason)}")
            {:error, "Failed to reach payment provider"}
        end

      {:error, reason} ->
        Logger.error("Failed to encode request body: #{inspect(reason)}")
        {:error, "Internal error"}
    end
  end

  defp get(path) do
    url = base_url() <> path
    headers = build_headers()

    Logger.info("pawaPay API GET #{path}")

    case Finch.build(:get, url, headers)
         |> Finch.request(HandmadeHub.Finch) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        case Jason.decode(resp_body) do
          {:ok, data} ->
            {:ok, data}

          {:error, _} ->
            {:error, "Invalid response from payment provider"}
        end

      {:ok, %Finch.Response{status: status, body: resp_body}} ->
        Logger.error("pawaPay API error #{status}: #{resp_body}")
        {:error, "Payment provider error (#{status})"}

      {:error, reason} ->
        Logger.error("pawaPay API request failed: #{inspect(reason)}")
        {:error, "Failed to reach payment provider"}
    end
  end

  defp build_headers do
    api_token = api_token()

    [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{api_token}"}
    ]
  end

  defp base_url do
    Application.get_env(:handmade_hub, :pawapay_base_url, "https://api.sandbox.pawapay.io")
  end

  defp api_token do
    Application.get_env(:handmade_hub, :pawapay_api_token)
  end

  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, _key, ""), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)
end
