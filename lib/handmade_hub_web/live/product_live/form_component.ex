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
        <.live_file_input upload={@uploads.image} />
        <:actions>
          <.button phx-disable-with="Saving...">Save Product</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> allow_upload(:image,
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000
      )
      |> assign_new(:form, fn ->
        to_form(Catalog.change_product(assigns.product))
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    changeset = Catalog.change_product(socket.assigns.product, product_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
        dest = Path.join("priv/static/uploads/products", entry.client_name)
        File.cp!(path, dest)
        {:ok, "/uploads/products/#{entry.client_name}"}
      end)

    image_url = List.first(uploaded_files)
    product_params = if image_url, do: Map.put(product_params, "image", image_url), else: product_params

    params =
      if socket.assigns.action == :new do
        Map.put(product_params, "artisan_id", socket.assigns.current_user.id)
      else
        product_params
      end
    save_product(socket, socket.assigns.action, params)
  end

  defp save_product(socket, :edit, product_params) do
    case Catalog.update_product(socket.assigns.product, product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_product(socket, :new, product_params) do
    case Catalog.create_product(product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
