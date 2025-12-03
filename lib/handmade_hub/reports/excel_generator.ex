defmodule HandmadeHub.Reports.ExcelGenerator do
  @moduledoc """
  Generates Excel (.xlsx) reports with formatting, multiple sheets, and styling.
  """

  alias HandmadeHubWeb.FormatHelpers

  @doc """
  Generates an Excel workbook from sheets.
  Returns a binary that can be written to a file or streamed.
  """
  def generate(sheets, _opts \\ []) do
    # Elixlsx expects a list of %Elixlsx.Sheet{} in the :sheets field
    workbook = %Elixlsx.Workbook{sheets: sheets}
    Elixlsx.write_to_memory(workbook)
  end

  @doc """
  Creates a worksheet from rows and headers.
  """
  def create_worksheet(name, headers, rows, _opts \\ []) do
    header_row = Enum.map(headers, fn header ->
      to_string(header)
    end)

    data_rows = Enum.map(rows, fn row ->
      Enum.map(headers, fn header ->
        value = Map.get(row, header, "")
        format_cell_value(value)
      end)
    end)

    all_rows = [header_row | data_rows]

    %Elixlsx.Sheet{
      name: name,
      rows: all_rows
    }
  end

  @doc """
  Generates Excel workbook for orders report.
  """
  def generate_orders_workbook(orders, opts \\ []) do
    title = Keyword.get(opts, :title, "Orders Report")
    generated_at = Keyword.get(opts, :generated_at, DateTime.utc_now())

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

    worksheet = create_worksheet("Orders", headers, rows, opts)

    # Add summary sheet if requested
    worksheets = if Keyword.get(opts, :include_summary, true) do
      summary_worksheet = create_summary_worksheet(orders, generated_at)
      [summary_worksheet, worksheet]
    else
      [worksheet]
    end

    generate(worksheets, opts)
  end

  @doc """
  Generates Excel workbook for monthly series data.
  """
  def generate_monthly_series_workbook(series, opts \\ []) do
    headers = ["Month", "Orders", "Revenue"]

    rows =
      Enum.map(series, fn item ->
        %{
          "Month" => item.period || "",
          "Orders" => item.count || 0,
          "Revenue" => format_currency(item.revenue)
        }
      end)

    worksheet = create_worksheet("Monthly Data", headers, rows, opts)
    generate([worksheet], opts)
  end

  # Private helper functions

  defp create_summary_worksheet(orders, generated_at) do
    total_orders = length(orders)
    total_revenue = calculate_total_revenue(orders)
    status_counts = calculate_status_counts(orders)

    headers = ["Metric", "Value"]
    rows = [
      %{"Metric" => "Report Generated", "Value" => format_datetime(generated_at)},
      %{"Metric" => "Total Orders", "Value" => total_orders},
      %{"Metric" => "Total Revenue", "Value" => format_currency(total_revenue)},
      %{"Metric" => "", "Value" => ""},
      %{"Metric" => "Status Breakdown", "Value" => ""}
    ] ++ Enum.map(status_counts, fn {status, count} ->
      %{"Metric" => "#{String.capitalize(status)} Orders", "Value" => count}
    end)

    create_worksheet("Summary", headers, rows)
  end

  defp calculate_total_revenue(orders) do
    orders
    |> Enum.filter(&(&1.payment_status == "paid"))
    |> Enum.reduce(Decimal.new("0"), fn order, acc ->
      total = order.total || Decimal.new("0")
      Decimal.add(acc, total)
    end)
  end

  defp calculate_status_counts(orders) do
    orders
    |> Enum.group_by(& &1.status)
    |> Enum.map(fn {status, orders_list} -> {status || "unknown", length(orders_list)} end)
    |> Enum.sort()
  end

  defp format_cell_value(value) when is_map(value), do: to_string(value)
  defp format_cell_value(value) when is_binary(value), do: value
  defp format_cell_value(value) when is_integer(value), do: value
  defp format_cell_value(value) when is_float(value), do: value
  defp format_cell_value(%Decimal{} = value), do: Decimal.to_float(value)
  defp format_cell_value(nil), do: ""
  defp format_cell_value(value), do: to_string(value)

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(_), do: ""

  defp format_currency(nil), do: Decimal.new("0")
  defp format_currency(%Decimal{} = amount), do: amount
  defp format_currency(amount) when is_number(amount), do: Decimal.from_float(amount / 1.0)
  defp format_currency(_), do: Decimal.new("0")

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
      length(order.order_items)
    else
      0
    end
  end
end
