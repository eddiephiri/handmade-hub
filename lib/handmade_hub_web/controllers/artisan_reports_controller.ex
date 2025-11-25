defmodule HandmadeHubWeb.ArtisanReportsController do
  use HandmadeHubWeb, :controller
  alias HandmadeHub.{ArtisanReports, ArtisanOrders}
  alias HandmadeHub.Reports.{CSVGenerator, ExcelGenerator, PDFGenerator}

  def export_sales_pdf(conn, params) do
    artisan_id = conn.assigns.current_user.id
    date_range = parse_date_range(params["date_range"])

    report_data = ArtisanReports.get_sales_report_data(artisan_id, date_range)

    assigns = %{
      title: "Sales Report",
      generated_at: DateTime.utc_now(),
      artisan: conn.assigns.current_user,
      stats: report_data.stats,
      orders: report_data.orders,
      date_range: report_data.date_range,
      layout: false
    }

    case PDFGenerator.generate_from_template(conn, "artisan_sales_report.html", assigns) do
      {:ok, pdf_binary} ->
        filename = "sales_report_#{timestamp()}.pdf"

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_binary)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate PDF: #{inspect(reason)}")
        |> redirect(to: ~p"/artisan/dashboard")
    end
  end

  def export_sales_excel(conn, params) do
    artisan_id = conn.assigns.current_user.id
    date_range = parse_date_range(params["date_range"])

    report_data = ArtisanReports.get_sales_report_data(artisan_id, date_range)
    orders = report_data.orders

    excel_binary = ExcelGenerator.generate_orders_workbook(orders, [
      title: "Sales Report",
      generated_at: DateTime.utc_now(),
      include_summary: true
    ])

    filename = "sales_report_#{timestamp()}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, excel_binary)
  end

  def export_sales_csv(conn, params) do
    artisan_id = conn.assigns.current_user.id
    date_range = parse_date_range(params["date_range"])

    report_data = ArtisanReports.get_sales_report_data(artisan_id, date_range)
    orders = report_data.orders

    csv = CSVGenerator.generate_orders_csv(orders, [
      title: "Sales Report",
      generated_at: DateTime.utc_now(),
      include_metadata: true
    ])

    filename = "sales_report_#{timestamp()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  def export_revenue_csv(conn, params) do
    artisan_id = conn.assigns.current_user.id
    date_range = parse_date_range(params["date_range"])

    stats = ArtisanOrders.get_artisan_stats(artisan_id, date_range)
    monthly_trend = ArtisanOrders.get_revenue_by_period(artisan_id, :monthly)

    headers = ["Month", "Revenue", "Orders"]
    rows =
      Enum.map(monthly_trend, fn item ->
        %{
          "Month" => format_period(item),
          "Revenue" => format_currency(item.revenue),
          "Orders" => to_string(item.orders || 0)
        }
      end)

    csv = CSVGenerator.generate(rows, headers, [
      title: "Revenue Report",
      generated_at: DateTime.utc_now(),
      include_metadata: true
    ])

    filename = "revenue_report_#{timestamp()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  # Private helper functions

  defp parse_date_range(nil), do: :all_time
  defp parse_date_range(""), do: :all_time
  defp parse_date_range(date_range) when is_binary(date_range) do
    case String.to_existing_atom(date_range) do
      atom when atom in [:today, :this_week, :this_month, :last_30_days, :this_year, :all_time] ->
        atom
      _ -> :all_time
    end
  rescue
    ArgumentError -> :all_time
  end
  defp parse_date_range(_), do: :all_time

  defp format_period(item) do
    cond do
      Map.has_key?(item, :month) ->
        "#{item.year}-#{String.pad_leading(to_string(item.month), 2, "0")}"
      Map.has_key?(item, :week) ->
        "#{item.year}-W#{String.pad_leading(to_string(item.week), 2, "0")}"
      Map.has_key?(item, :date) ->
        Calendar.strftime(item.date, "%Y-%m-%d")
      true ->
        "Unknown"
    end
  end

  defp format_currency(nil), do: "0.00"
  defp format_currency(%Decimal{} = amount) do
    HandmadeHubWeb.FormatHelpers.format_currency(amount)
  end
  defp format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount / 1.0, decimals: 2)
  end
  defp format_currency(_), do: "0.00"

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix()
    |> Integer.to_string()
  end
end
