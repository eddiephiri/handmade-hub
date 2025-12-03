defmodule HandmadeHubWeb.ReportHTML do
  @moduledoc """
  This module contains pages rendered by Report controllers.
  Used for PDF generation from templates.
  """
  use HandmadeHubWeb, :html

  embed_templates "report_html/*"

  # Helper for artisan sales report date range label
  defp format_date_range(:today), do: "Today"
  defp format_date_range(:this_week), do: "This Week"
  defp format_date_range(:this_month), do: "This Month"
  defp format_date_range(:last_30_days), do: "Last 30 Days"
  defp format_date_range(:this_year), do: "This Year"
  defp format_date_range(:all_time), do: "All Time"
  defp format_date_range(_), do: "All Time"
end
