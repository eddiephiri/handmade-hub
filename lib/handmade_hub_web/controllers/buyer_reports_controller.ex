defmodule HandmadeHubWeb.BuyerReportsController do
  use HandmadeHubWeb, :controller
  alias HandmadeHub.BuyerReports
  alias HandmadeHub.Reports.{CSVGenerator, ExcelGenerator, PDFGenerator}

  def export_orders_pdf(conn, params) do
    buyer_id = conn.assigns.current_user.id
    filters = extract_filters(params)

    report_data = BuyerReports.get_order_history_data(buyer_id, filters)

    assigns = %{
      title: "Order History Report",
      generated_at: DateTime.utc_now(),
      buyer: conn.assigns.current_user,
      orders: report_data.orders,
      stats: report_data.stats,
      layout: false
    }

    case PDFGenerator.generate_from_template(conn, "buyer_order_history.html", assigns) do
      {:ok, pdf_binary} ->
        filename = "order_history_#{timestamp()}.pdf"

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_binary)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate PDF: #{inspect(reason)}")
        |> redirect(to: ~p"/buyer/dashboard")
    end
  end

  def export_orders_excel(conn, params) do
    buyer_id = conn.assigns.current_user.id
    filters = extract_filters(params)

    report_data = BuyerReports.get_order_history_data(buyer_id, filters)
    orders = report_data.orders

    excel_binary = ExcelGenerator.generate_orders_workbook(orders, [
      title: "Order History Report",
      generated_at: DateTime.utc_now(),
      include_summary: true
    ])

    filename = "order_history_#{timestamp()}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, excel_binary)
  end

  def export_orders_csv(conn, params) do
    buyer_id = conn.assigns.current_user.id
    filters = extract_filters(params)

    report_data = BuyerReports.get_order_history_data(buyer_id, filters)
    orders = report_data.orders

    csv = CSVGenerator.generate_orders_csv(orders, [
      title: "Order History Report",
      generated_at: DateTime.utc_now(),
      include_metadata: true
    ])

    filename = "order_history_#{timestamp()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  def export_purchases_excel(conn, params) do
    buyer_id = conn.assigns.current_user.id
    report_data = BuyerReports.get_purchase_summary_data(buyer_id)
    orders = report_data.orders

    excel_binary = ExcelGenerator.generate_orders_workbook(orders, [
      title: "Purchase Summary Report",
      generated_at: DateTime.utc_now(),
      include_summary: true
    ])

    filename = "purchase_summary_#{timestamp()}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, excel_binary)
  end

  # Private helper functions

  defp extract_filters(params) do
    %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_date_range(params["start_date"], params["end_date"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp maybe_add_date_range(filters, nil, nil), do: filters
  defp maybe_add_date_range(filters, start_date, nil) when is_binary(start_date) do
    case Date.from_iso8601(start_date) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        Map.put(filters, :start_date, datetime)

      _ ->
        filters
    end
  end
  defp maybe_add_date_range(filters, nil, end_date) when is_binary(end_date) do
    case Date.from_iso8601(end_date) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        Map.put(filters, :end_date, datetime)

      _ ->
        filters
    end
  end
  defp maybe_add_date_range(filters, start_date, end_date) when is_binary(start_date) and is_binary(end_date) do
    filters
    |> maybe_add_date_range(start_date, nil)
    |> maybe_add_date_range(nil, end_date)
  end
  defp maybe_add_date_range(filters, _, _), do: filters

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix()
    |> Integer.to_string()
  end
end
