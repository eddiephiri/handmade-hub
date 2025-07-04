defmodule HandmadeHubWeb.ProductLive.FormComponent do
  use HandmadeHubWeb, :live_component

  alias HandmadeHub.Catalog

  def mount(_params, _session, socket) do
    if socket.assigns.current_user.role != "artisan" do
      {:halt, redirect(socket, to: ~p"/")}
    else
      {:ok, assign(socket, :products, Catalog.list_user_products(socket.assigns.current_user.id))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage product records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />
        <.input field={@form[:price]} type="number" label="Price" step="any" />
        <.input field={@form[:quantity]} type="number" label="Quantity" />
        <div class="mt-4">
          <label class="block font-medium mb-1">Product Images (up to 5)</label>
          <.live_file_input upload={@uploads.images} class="mb-2" />
          <div class="flex flex-wrap gap-2 mt-2">
            <%= for entry <- @uploads.images.entries do %>
              <div class="relative w-24 h-24 border rounded overflow-hidden flex items-center justify-center">
                <img :if={entry.client_name} src={live_img_preview(entry)} class="object-cover w-full h-full" />
                <span class="absolute bottom-1 left-1 bg-white text-xs px-1 rounded">Uploading...</span>
              </div>
            <% end %>
          </div>
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">Save Product</.button>
        </:actions>
      </.simple_form>

      <%= if @product && @product.id && length(@product_images) > 0 do %>
        <div class="mt-6">
          <h3 class="font-semibold mb-2">Product Images</h3>
          <div class="flex flex-wrap gap-4">
            <%= for image <- @product_images do %>
              <div class="relative w-28 h-28 border rounded overflow-hidden flex flex-col items-center justify-center bg-gray-50">
                <img src={image.image_url} alt="Product Image" class="object-cover w-full h-full" />
                <%= if image.is_primary do %>
                  <span class="absolute top-1 left-1 bg-blue-600 text-white text-xs px-2 py-0.5 rounded">Primary</span>
                <% end %>
                <div class="absolute bottom-1 left-1 right-1 flex justify-between gap-1">
                  <button phx-click="set_primary_image" phx-value-id={image.id} phx-value-product_id={image.product_id} class="text-xs bg-blue-500 hover:bg-blue-700 text-white px-2 py-0.5 rounded">Set as Primary</button>
                  <button phx-click="delete_image" phx-value-id={image.id} phx-value-product_id={image.product_id} class="text-xs bg-red-500 hover:bg-red-700 text-white px-2 py-0.5 rounded">Delete</button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> allow_upload(:images,
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 5,
        max_file_size: 5_000_000
      )
      |> assign_new(:form, fn ->
        to_form(Catalog.change_product(assigns.product))
      end)
      |> assign(:product_images, (if assigns[:product], do: Catalog.list_product_images(assigns.product.id), else: []))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset = Catalog.change_product(socket.assigns.product, product_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    params =
      if socket.assigns.action == :new do
        Map.put(product_params, "artisan_id", socket.assigns.current_user.id)
      else
        product_params
      end

    case save_product(socket, socket.assigns.action, params) do
      {:ok, product} ->
        send(self(), {:refresh_images, product.id})
        notify_parent({:saved, product})
        {:noreply,
         socket
         |> put_flash(:info, "Product #{if socket.assigns.action == :edit, do: "updated", else: "created"} successfully")}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("set_primary_image", %{"id" => image_id, "product_id" => product_id}, socket) do
    Catalog.set_primary_product_image(String.to_integer(product_id), String.to_integer(image_id))
    {:noreply, assign(socket, :product_images, Catalog.list_product_images(product_id))}
  end

  def handle_event("delete_image", %{"id" => image_id, "product_id" => product_id}, socket) do
    Catalog.delete_product_image(String.to_integer(image_id))
    {:noreply, assign(socket, :product_images, Catalog.list_product_images(product_id))}
  end

  def handle_info({:refresh_images, product_id}, socket) do
    {:noreply, assign(socket, :product_images, Catalog.list_product_images(product_id))}
  end

  defp save_product(socket, :edit, product_params) do
    Catalog.update_product(socket.assigns.product, product_params)
  end

  defp save_product(socket, :new, product_params) do
    Catalog.create_product(product_params)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
