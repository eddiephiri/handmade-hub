defmodule HandmadeHubWeb.AdminReportsController do
  use HandmadeHubWeb, :controller
  alias HandmadeHub.Orders

  def export_orders_csv(conn, _params) do
    series = Orders.orders_monthly_series(12)
    csv = ["month,orders,revenue" | Enum.map(series, fn r -> "#{r.period},#{r.count},#{r.revenue}" end)] |> Enum.join("\n")

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="orders_report.csv"))
    |> send_resp(200, csv)
  end
end
