defmodule HandmadeHubWeb.PawapayWebhookController do
  use HandmadeHubWeb, :controller

  require Logger

  alias HandmadeHub.Payments

  @doc """
  Unified callback endpoint for all pawaPay webhooks.
  Handles deposits, payouts, and refunds.
  """
  def callback(conn, params) do
    Logger.info("Received pawaPay callback: #{inspect(params)}")

    # Determine callback type and route to appropriate handler
    result =
      cond do
        Map.has_key?(params, "depositId") ->
          process_deposit_callback(params)

        Map.has_key?(params, "payoutId") ->
          process_payout_callback(params)

        Map.has_key?(params, "refundId") ->
          process_refund_callback(params)

        true ->
          Logger.warning("Unknown callback type: #{inspect(params)}")
          {:error, :unknown_type}
      end

    case result do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "success"})

      {:error, reason} ->
        Logger.error("Callback processing failed: #{inspect(reason)}")

        conn
        |> put_status(:ok) # Still return 200 to prevent retries
        |> json(%{status: "error", reason: inspect(reason)})
    end
  end

  # Private functions

  defp process_deposit_callback(params) do
    Logger.info("Processing deposit callback for depositId: #{params["depositId"]}")
    Payments.process_deposit_callback(params)
  end

  defp process_payout_callback(params) do
    Logger.info("Processing payout callback for payoutId: #{params["payoutId"]}")
    Payments.process_payout_callback(params)
  end

  defp process_refund_callback(params) do
    Logger.info("Processing refund callback for refundId: #{params["refundId"]}")
    Payments.process_refund_callback(params)
  end
end
