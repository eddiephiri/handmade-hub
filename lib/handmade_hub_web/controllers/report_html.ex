defmodule HandmadeHubWeb.ReportHTML do
  @moduledoc """
  This module contains pages rendered by Report controllers.
  Used for PDF generation from templates.
  """
  use HandmadeHubWeb, :html

  embed_templates "report_html/*"
end
