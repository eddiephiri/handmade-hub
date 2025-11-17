defmodule HandmadeHubWeb.Admin.DeliveriesLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Delivery

  @status_options [
    {"All statuses", ""},
    {"Dispatched", "dispatched"},
    {"In transit", "in_transit"},
    {"Delivered", "delivered"},
    {"Failed", "failed"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    deliveries = Delivery.list_assignments_admin()

    {:ok,
     socket
     |> assign(search: "", status: "")
     |> assign(deliveries: deliveries, status_counts: status_counts(deliveries))
     |> assign(status_options: @status_options)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(search: q) |> refresh_deliveries()}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, socket |> assign(status: status) |> refresh_deliveries()}
  end

  defp refresh_deliveries(socket) do
    filters = %{
      search: blank(socket.assigns.search),
      status: blank(socket.assigns.status)
    }

    deliveries = Delivery.list_assignments_admin(filters)

    assign(socket,
      deliveries: deliveries,
      status_counts: status_counts(deliveries)
    )
  end

  defp status_counts(deliveries) do
    Enum.reduce(deliveries, %{"total" => Enum.count(deliveries)}, fn delivery, acc ->
      Map.update(acc, delivery.status, 1, &(&1 + 1))
    end)
  end

  defp blank(value) when value in [nil, ""], do: nil
  defp blank(value), do: value

  def status_badge_class("delivered"), do: "bg-emerald-50 text-emerald-700 border border-emerald-200"
  def status_badge_class("in_transit"), do: "bg-blue-50 text-blue-700 border border-blue-200"
  def status_badge_class("dispatched"), do: "bg-amber-50 text-amber-700 border border-amber-200"
  def status_badge_class("failed"), do: "bg-rose-50 text-rose-700 border border-rose-200"
  def status_badge_class(_status), do: "bg-slate-50 text-slate-600 border border-slate-200"

  def format_status(status) when is_binary(status) do
    status
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def format_status(_), do: "—"

  def format_timestamp(nil), do: "—"

  def format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y • %H:%M")
  end

  def format_timestamp(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> format_timestamp()
  end

  def delivery_customer_name(%{order: order}) when not is_nil(order) do
    cond do
      present?(order.customer_name) -> order.customer_name
      order.user && present?(order.user.name) -> order.user.name
      order.user && present?(order.user.email) -> order.user.email
      present?(order.customer_email) -> order.customer_email
      true -> "—"
    end
  end

  def delivery_customer_name(_), do: "—"

  def delivery_customer_contact(%{order: order}) when not is_nil(order) do
    cond do
      present?(order.customer_phone) -> order.customer_phone
      order.user && present?(order.user.email) -> order.user.email
      true -> "—"
    end
  end

  def delivery_customer_contact(_), do: "—"

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  attr :status_counts, :map, required: true

  defp summary_cards(assigns) do
    assigns =
      assign(assigns,
        total: Map.get(assigns.status_counts, "total", 0),
        in_transit: Map.get(assigns.status_counts, "in_transit", 0),
        delivered: Map.get(assigns.status_counts, "delivered", 0),
        failed: Map.get(assigns.status_counts, "failed", 0)
      )

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4 mb-6">
      <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-sm">
        <p class="text-sm text-slate-500">Total deliveries</p>
        <p class="text-3xl font-semibold text-slate-900 mt-2"><%= @total %></p>
      </div>
      <div class="bg-white border border-blue-100 rounded-2xl p-5 shadow-sm">
        <p class="text-sm text-slate-500">In transit</p>
        <p class="text-3xl font-semibold text-blue-600 mt-2"><%= @in_transit %></p>
      </div>
      <div class="bg-white border border-emerald-100 rounded-2xl p-5 shadow-sm">
        <p class="text-sm text-slate-500">Delivered</p>
        <p class="text-3xl font-semibold text-emerald-600 mt-2"><%= @delivered %></p>
      </div>
      <div class="bg-white border border-rose-100 rounded-2xl p-5 shadow-sm">
        <p class="text-sm text-slate-500">Failed</p>
        <p class="text-3xl font-semibold text-rose-600 mt-2"><%= @failed %></p>
      </div>
    </div>
    """
  end
end
