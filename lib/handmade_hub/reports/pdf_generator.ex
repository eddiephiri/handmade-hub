defmodule HandmadeHub.Reports.PDFGenerator do
  @moduledoc """
  Generates PDF reports from HTML templates using pdf_generator library.
  """

  alias HandmadeHubWeb.Endpoint

  @doc """
  Generates a PDF from an HTML string.
  """
  def generate_from_html(html, opts \\ []) do
    default_opts = [
      page_size: "A4",
      orientation: "portrait",
      print_media_type: true
    ]

    options = Keyword.merge(default_opts, opts)

    case PdfGenerator.generate_binary(html, options) do
      {:ok, pdf_binary} -> {:ok, pdf_binary}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a PDF from a Phoenix template.
  """
  def generate_from_template(conn, template, assigns, opts \\ []) do
    html = Phoenix.Template.render_to_string(
      HandmadeHubWeb.ReportHTML,
      template,
      Map.merge(assigns, %{conn: conn})
    )

    generate_from_html(html, opts)
  end

  @doc """
  Generates a PDF for orders report.
  """
  def generate_orders_pdf(conn, orders, stats, opts \\ []) do
    title = Keyword.get(opts, :title, "Orders Report")
    generated_at = Keyword.get(opts, :generated_at, DateTime.utc_now())

    assigns = %{
      title: title,
      generated_at: generated_at,
      orders: orders,
      stats: stats,
      layout: false
    }

    generate_from_template(conn, "admin_orders_report.html", assigns, opts)
  end

  @doc """
  Generates a PDF for monthly series data.
  """
  def generate_monthly_series_pdf(conn, series, opts \\ []) do
    title = Keyword.get(opts, :title, "Monthly Analytics Report")
    generated_at = Keyword.get(opts, :generated_at, DateTime.utc_now())

    assigns = %{
      title: title,
      generated_at: generated_at,
      series: series,
      layout: false
    }

    generate_from_template(conn, "monthly_series_report.html", assigns, opts)
  end
end
