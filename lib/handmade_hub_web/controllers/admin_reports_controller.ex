defmodule HandmadeHubWeb.AdminReportsController do
  use HandmadeHubWeb, :controller
  alias HandmadeHub.{Orders, Reports}
  alias HandmadeHub.Reports.{CSVGenerator, ExcelGenerator, PDFGenerator}

  def export_orders_csv(conn, params) do
    filters = extract_filters(params)
    orders = Reports.get_orders_for_report(filters)
    stats = Reports.get_platform_order_stats(filters)

    csv = CSVGenerator.generate_orders_csv(orders, [
      title: "Orders Report",
      generated_at: DateTime.utc_now(),
      include_metadata: true
    ])

    filename = "orders_report_#{timestamp()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  def export_orders_pdf(conn, params) do
    filters = extract_filters(params)
    orders = Reports.get_orders_for_report(filters)
    stats = Reports.get_platform_order_stats(filters)

    case PDFGenerator.generate_orders_pdf(conn, orders, stats, [
      title: "Orders Report",
      generated_at: DateTime.utc_now()
    ]) do
      {:ok, pdf_binary} ->
        filename = "orders_report_#{timestamp()}.pdf"

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_binary)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate PDF: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/dashboard")
    end
  end

  def export_orders_excel(conn, params) do
    filters = extract_filters(params)
    orders = Reports.get_orders_for_report(filters)

    excel_binary = ExcelGenerator.generate_orders_workbook(orders, [
      title: "Orders Report",
      generated_at: DateTime.utc_now(),
      include_summary: true
    ])

    filename = "orders_report_#{timestamp()}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, excel_binary)
  end

  def export_monthly_series_csv(conn, params) do
    months = Map.get(params, "months", "12") |> String.to_integer()
    series = Orders.orders_monthly_series(months)

    csv = CSVGenerator.generate_monthly_series_csv(series, [
      title: "Monthly Orders & Revenue Report",
      generated_at: DateTime.utc_now(),
      include_metadata: true
    ])

    filename = "monthly_series_#{timestamp()}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end

  def export_monthly_series_excel(conn, params) do
    months = Map.get(params, "months", "12") |> String.to_integer()
    series = Orders.orders_monthly_series(months)

    excel_binary = ExcelGenerator.generate_monthly_series_workbook(series, [
      title: "Monthly Orders & Revenue Report",
      generated_at: DateTime.utc_now()
    ])

    filename = "monthly_series_#{timestamp()}.xlsx"

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, excel_binary)
  end

  def export_platform_performance_pdf(conn, params) do
    order_stats = Reports.get_platform_order_stats()
    user_stats = Reports.get_platform_user_stats()
    product_stats = Reports.get_platform_product_stats()
    financial_stats = Reports.get_financial_stats()

    assigns = %{
      title: "Platform Performance Report",
      generated_at: DateTime.utc_now(),
      order_stats: order_stats,
      user_stats: user_stats,
      product_stats: product_stats,
      financial_stats: financial_stats,
      layout: false
    }

    case PDFGenerator.generate_from_template(conn, "platform_performance_report", assigns) do
      {:ok, pdf_binary} ->
        filename = "platform_performance_#{timestamp()}.pdf"

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_binary)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate PDF: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/dashboard")
    end
  end

  # Private helper functions

  defp extract_filters(params) do
    %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:payment_status, params["payment_status"])
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
