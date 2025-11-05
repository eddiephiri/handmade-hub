defmodule HandmadeHubWeb.Admin.DeliveryRidersLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Delivery

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(riders: Delivery.list_riders(), form: nil)}
  end

  @impl true
  def handle_event("add_rider", _params, socket) do
    changeset = Delivery.change_rider(%Delivery.Rider{})
    form = to_form(changeset)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save_rider", %{"rider" => rider_params}, socket) do
    case Delivery.create_rider(rider_params) do
      {:ok, _rider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rider created successfully")
         |> assign(riders: Delivery.list_riders(), form: nil)}

      {:error, changeset} ->
        form = to_form(changeset)
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, form: nil)}
  end
end
