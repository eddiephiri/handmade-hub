defmodule HandmadeHubWeb.Admin.DeliveryShowLive do
  use HandmadeHubWeb, :live_view

  import HandmadeHubWeb.Admin.DeliveriesLive,
    only: [status_badge_class: 1, format_status: 1, format_timestamp: 1]

  alias HandmadeHub.Delivery
  alias HandmadeHubWeb.FormatHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    delivery = Delivery.get_assignment_with_details!(id)

    {:noreply,
     socket
     |> assign(:delivery, delivery)
     |> assign(:shipping, delivery.order && delivery.order.shipping_address)
     |> assign(:timeline, timeline_for(delivery))}
  end

  defp timeline_for(delivery) do
    [
      %{
        label: "Assigned",
        description: assigned_description(delivery),
        at: delivery.inserted_at
      },
      %{
        label: "Last update",
        description: "Status marked as #{format_status(delivery.status)}",
        at: delivery.updated_at || delivery.inserted_at
      }
    ]
  end

  defp assigned_description(delivery) do
    cond do
      delivery.assigned_by_admin ->
        "Assigned by #{delivery.assigned_by_admin.username}"

      true ->
        "Assigned automatically"
    end
  end

  defp shipping_line(nil), do: "—"

  defp shipping_line(address) do
    [
      address.address_line_1,
      address.address_line_2,
      address.city,
      address.province,
      address.country
    ]
    |> Enum.reject(&is_nil_or_blank/1)
    |> Enum.join(", ")
  end

  defp is_nil_or_blank(value) when is_binary(value), do: String.trim(value) == ""
  defp is_nil_or_blank(nil), do: true
  defp is_nil_or_blank(_), do: false

  defp customer_email(delivery) do
    delivery.order &&
      (delivery.order.customer_email ||
         (delivery.order.user && delivery.order.user.email))
  end

  defp customer_name(delivery) do
    delivery.order &&
      (delivery.order.customer_name ||
         (delivery.order.user && delivery.order.user.name))
  end

  defp customer_phone(delivery) do
    delivery.order && delivery.order.customer_phone
  end

  defp order_total(delivery) do
    delivery.order && delivery.order.total && FormatHelpers.format_currency(delivery.order.total)
  end
end
