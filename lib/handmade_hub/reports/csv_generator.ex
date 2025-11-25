defmodule HandmadeHub.Reports.CSVGenerator do
  @moduledoc """
  Generates CSV reports with proper formatting, escaping, and metadata.
  """

  alias HandmadeHubWeb.FormatHelpers

  @doc """
  Generates a CSV string from a list of maps or structs.
  """
  def generate(rows, headers, opts \\ []) do
    include_metadata = Keyword.get(opts, :include_metadata, true)
    title = Keyword.get(opts, :title, "Report")
    generated_at = Keyword.get(opts, :generated_at, DateTime.utc_now())

    lines = []

    lines =
      if include_metadata do
        lines
        |> add_metadata(title, generated_at)
      else
        lines
      end

    lines = lines ++ [format_headers(headers)]

    rows
    |> Enum.map(&format_row(&1, headers))
    |> Enum.reduce(lines, fn row, acc -> acc ++ [row] end)
    |> Enum.join("\n")
  end

  @doc """
  Generates CSV for order data.
  """
  def generate_orders_csv(orders, opts \\ []) do
    headers = [
      "Order Number",
      "Date",
      "Customer Name",
      "Customer Email",
      "Status",
      "Payment Status",
      "Total Amount",
      "Items Count"
    ]

    rows =
      Enum.map(orders, fn order ->
        %{
          "Order Number" => order.order_number || "",
          "Date" => format_datetime(order.inserted_at),
          "Customer Name" => order.customer_name || get_user_name(order),
          "Customer Email" => order.customer_email || get_user_email(order),
          "Status" => order.status || "",
          "Payment Status" => order.payment_status || "",
          "Total Amount" => format_currency(order.total),
          "Items Count" => get_items_count(order)
        }
      end)

    generate(rows, headers, opts)
  end

  @doc """
  Generates CSV for monthly series data.
  """
  def generate_monthly_series_csv(series, opts \\ []) do
    headers = ["Month", "Orders", "Revenue"]

    rows =
      Enum.map(series, fn item ->
        %{
          "Month" => item.period || "",
          "Orders" => to_string(item.count || 0),
          "Revenue" => format_currency(item.revenue)
        }
      end)

    generate(rows, headers, opts)
  end

  # Private helper functions

  defp add_metadata(lines, title, generated_at) do
    [
      "# #{title}",
      "# Generated: #{format_datetime(generated_at)}",
      ""
    ]
  end

  defp format_headers(headers) do
    headers
    |> Enum.map(&escape_csv_field/1)
    |> Enum.join(",")
  end

  defp format_row(data, headers) do
    headers
    |> Enum.map(fn header ->
      value = Map.get(data, header, "")
      escape_csv_field(to_string(value))
    end)
    |> Enum.join(",")
  end

  defp escape_csv_field(field) when is_binary(field) do
    if String.contains?(field, [",", "\"", "\n"]) do
      "\"#{String.replace(field, "\"", "\"\"")}\""
    else
      field
    end
  end

  defp escape_csv_field(field), do: escape_csv_field(to_string(field))

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(_), do: ""

  defp format_currency(nil), do: "0.00"
  defp format_currency(%Decimal{} = amount) do
    FormatHelpers.format_currency(amount)
  end
  defp format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount / 1.0, decimals: 2)
  end
  defp format_currency(_), do: "0.00"

  defp get_user_name(order) do
    if order.user do
      order.user.name || ""
    else
      ""
    end
  end

  defp get_user_email(order) do
    if order.user do
      order.user.email || ""
    else
      ""
    end
  end

  defp get_items_count(order) do
    if order.order_items do
      to_string(length(order.order_items))
    else
      "0"
    end
  end
end
