defmodule HandmadeHub.Delivery.Simulator do
  @moduledoc """
  Periodic job that simulates deliveries by marking assignments and their
  orders as delivered once the configured delivery window has elapsed.
  """

  import Ecto.Query, warn: false
  require Logger

  alias HandmadeHub.{Delivery, Orders, Repo}
  alias HandmadeHub.Delivery.Assignment

  @default_delivery_minutes 5

  @doc """
  Processes assignments that have been in a dispatchable state longer
  than the configured delivery window and marks them as delivered.
  This callback is intended to be triggered by the Quantum scheduler.
  """
  def process_deliveries(opts \\ []) do
    cutoff = DateTime.add(DateTime.utc_now(), -delivery_delay_seconds(opts), :second)

    assignments =
      Assignment
      |> where([a], a.status in ["dispatched", "in_transit"])
      |> where([a], a.updated_at <= ^cutoff)
      |> Repo.all()

    {completed, errors} =
      Enum.reduce(assignments, {0, 0}, fn assignment, {done, failed} ->
        case complete_assignment(assignment) do
          :ok -> {done + 1, failed}
          {:error, _} -> {done, failed + 1}
        end
      end)

    Logger.info(
      "Delivery simulator processed #{completed} assignment(s) with #{errors} error(s)"
    )

    {:ok, %{completed: completed, errors: errors}}
  end

  defp complete_assignment(assignment) do
    case Delivery.update_assignment_status(assignment.id, "delivered") do
      {:ok, updated_assignment} ->
        case maybe_mark_order_delivered(updated_assignment.order) do
          {:ok, _order} ->
            Logger.debug("Simulated delivery for assignment #{assignment.id}")
            :ok

          {:error, reason} ->
            Logger.warning(
              "Assignment #{assignment.id} marked delivered but failed to update order: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning(
          "Failed to simulate delivery for assignment #{assignment.id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp maybe_mark_order_delivered(nil), do: {:error, :order_not_loaded}

  defp maybe_mark_order_delivered(order) do
    case order.status do
      "delivered" -> {:ok, order}
      _ -> Orders.update_order_status(order.id, "delivered")
    end
  end

  defp delivery_delay_seconds(opts) do
    minutes =
      Keyword.get_lazy(opts, :delivery_time_minutes, fn ->
        Application.get_env(:handmade_hub, :delivery_simulator, [])
        |> Keyword.get(:delivery_time_minutes, @default_delivery_minutes)
      end)

    if is_integer(minutes) and minutes >= 0 do
      minutes * 60
    else
      Logger.warning(
        "Invalid delivery simulation window #{inspect(minutes)} supplied; using default #{@default_delivery_minutes} minutes"
      )

      @default_delivery_minutes * 60
    end
  end
end
