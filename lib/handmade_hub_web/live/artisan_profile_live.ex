defmodule HandmadeHubWeb.ArtisanProfileLive do
  use HandmadeHubWeb, :live_view
  import HandmadeHubWeb.FormatHelpers

  alias HandmadeHub.Accounts
  alias HandmadeHub.Catalog
  alias HandmadeHub.Notifications

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    artisan =
      id
      |> String.to_integer()
      |> Accounts.get_user!()

    if artisan.role != "artisan" do
      {:ok,
       socket
       |> put_flash(:error, "Artisan not found.")
       |> push_navigate(to: ~p"/browse")}
    else
      products = Catalog.list_user_products(artisan.id)
      avg = HandmadeHub.Reviews.average_artisan_rating(artisan.id)
      reviews = HandmadeHub.Reviews.list_artisan_reviews(artisan.id)

      {:ok,
       assign(socket,
         page_title: (artisan.name || artisan.email) <> " · Artisan",
         artisan: artisan,
         products: products,
         show_message_modal: false,
         message_form: to_form(%{}, as: :message),
         artisan_rating_avg: (case avg do %Decimal{} = d -> Decimal.to_float(d); n when is_integer(n) -> n * 1.0; n when is_float(n) -> n end),
         artisan_reviews: reviews,
         artisan_review_form: to_form(%{}, as: :review)
       )}
    end
  end

  @impl true
  def handle_event("open_message_artisan", _params, socket) do
    {:noreply, assign(socket, show_message_modal: true)}
  end

  def handle_event("close_message_artisan", _params, socket) do
    {:noreply, assign(socket, show_message_modal: false)}
  end

  def handle_event("send_message_artisan", %{"message" => msg_params}, socket) do
    current_user = socket.assigns.current_user

    if is_nil(current_user) do
      {:noreply,
       socket
       |> put_flash(:error, "Please log in to message the artisan.")
       |> push_navigate(to: ~p"/users/log_in")}
    else
      subject = Map.get(msg_params, "subject", "Message from Buyer on HandmadeHub")
      body = Map.get(msg_params, "body", "")

      _ =
        Notifications.enqueue_email(%{
          to: socket.assigns.artisan.email,
          reply_to: current_user.email,
          subject: subject,
          text_body:
            "From: #{current_user.name || current_user.email}\nEmail: #{current_user.email}\n\n#{body}",
          type: "artisan_message"
        })

      # Create in-app message too
      _ = HandmadeHub.Messaging.send_message(%{
        sender_id: current_user.id,
        recipient_id: socket.assigns.artisan.id,
        subject: subject,
        body: body
      })

      {:noreply,
       socket
       |> put_flash(:info, "Your message has been sent to the artisan.")
       |> assign(show_message_modal: false)
       |> push_navigate(to: ~p"/messages?with=#{socket.assigns.artisan.id}&from=browse")}
    end
  end

  def handle_event("submit_artisan_review", %{"review" => %{"rating" => rating, "comment" => comment}}, socket) do
    current_user = socket.assigns.current_user
    if is_nil(current_user) do
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    else
      {:ok, _} = HandmadeHub.Reviews.create_artisan_review(current_user.id, socket.assigns.artisan.id, String.to_integer(rating), comment)
      {:noreply,
       assign(socket,
         artisan_rating_avg: (case HandmadeHub.Reviews.average_artisan_rating(socket.assigns.artisan.id) do %Decimal{} = d -> Decimal.to_float(d); n when is_integer(n) -> n * 1.0; n when is_float(n) -> n end),
         artisan_reviews: HandmadeHub.Reviews.list_artisan_reviews(socket.assigns.artisan.id),
         artisan_review_form: to_form(%{}, as: :review)
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="flex items-center gap-4 mb-8">
          <.link navigate={~p"/browse"} class="text-indigo-600 hover:text-indigo-700 inline-flex items-center">
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Browse
          </.link>
        </div>

        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 mb-8">
          <div class="flex items-start gap-4">
            <%= if @artisan.profile_image do %>
              <img src={@artisan.profile_image} alt={@artisan.name} class="w-20 h-20 rounded-full object-cover ring-2 ring-indigo-100" />
            <% else %>
              <div class="w-20 h-20 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-xl font-bold">
                <%= (@artisan.name || @artisan.email) |> String.first() |> String.upcase() %>
              </div>
            <% end %>
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-gray-900"><%= @artisan.name || @artisan.email %></h1>
              <p class="text-gray-600 mt-1">Artisan based in Lusaka</p>
              <div class="mt-2 flex items-center gap-2">
                <div class="flex">
                  <%= for i <- 1..5 do %>
                    <svg class={"w-4 h-4 " <> if i <= (Float.round(@artisan_rating_avg) |> trunc), do: "text-yellow-400", else: "text-gray-300"} fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  <% end %>
                </div>
                <span class="text-xs text-gray-600">(<%= :erlang.float_to_binary(@artisan_rating_avg, decimals: 1) %>)</span>
              </div>
              <%= if @artisan.bio do %>
                <p class="text-gray-700 mt-3"><%= @artisan.bio %></p>
              <% end %>
              <div class="mt-4 flex gap-3">
                <.button phx-click="open_message_artisan" class="bg-indigo-600 hover:bg-indigo-700 text-white">Message Artisan</.button>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-10">
          <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 lg:col-span-1">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">Skills & Techniques</h3>
            <%= if (@artisan.skills || []) == [] do %>
              <p class="text-sm text-gray-500">This artisan hasn’t shared skills yet.</p>
            <% else %>
              <div class="flex flex-wrap gap-2">
                <%= for skill <- @artisan.skills do %>
                  <span class="px-3 py-1 rounded-full bg-indigo-50 text-indigo-700 text-sm font-medium"><%= skill %></span>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 lg:col-span-1">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">Highlights</h3>
            <%= if (@artisan.highlights || []) == [] do %>
              <p class="text-sm text-gray-500">No highlights provided.</p>
            <% else %>
              <ul class="space-y-2 list-disc list-inside text-gray-700 text-sm">
                <%= for highlight <- Enum.take(@artisan.highlights, 6) do %>
                  <li><%= highlight %></li>
                <% end %>
              </ul>
            <% end %>
          </div>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 lg:col-span-1">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">Story</h3>
            <%= if @artisan.story && String.trim(@artisan.story) != "" do %>
              <p class="text-sm text-gray-700 leading-6"><%= @artisan.story %></p>
            <% else %>
              <p class="text-sm text-gray-500">This artisan hasn’t shared their story yet.</p>
            <% end %>
          </div>
        </div>

        <div>
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Products by <%= @artisan.name || "this artisan" %></h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for product <- @products do %>
              <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                <div class="aspect-square bg-gray-50">
                  <img src={product.image || (product.product_images |> List.first() |> then(&(&1 && &1.image_url)))} alt={product.name} class="w-full h-full object-cover" />
                </div>
                <div class="p-4">
                  <h3 class="font-semibold text-gray-900 line-clamp-1"><%= product.name %></h3>
                  <p class="text-sm text-gray-600 line-clamp-2 mb-3"><%= product.description %></p>
                  <div class="flex items-center justify-between">
                    <span class="font-bold text-gray-900"><%= format_currency(product.price) %></span>
                    <.link navigate={~p"/browse/#{product.id}"} class="text-indigo-600 hover:text-indigo-700 text-sm font-medium">View</.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="mt-10">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Reviews</h2>
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">Leave a Review for this Artisan</h3>
            <.form for={@artisan_review_form} phx-submit="submit_artisan_review" class="space-y-3">
              <div id="artisan-rating" class="flex items-center gap-2" role="radiogroup" aria-label="Rating" phx-hook="StarRating">
                <%= for i <- 1..5 do %>
                  <label class="cursor-pointer">
                    <input type="radio" name="review[rating]" value={i} class="sr-only" />
                    <svg data-star class="w-6 h-6 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </label>
                <% end %>
              </div>
              <.input field={@artisan_review_form[:comment]} type="textarea" placeholder="Write feedback (optional)" />
              <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white">Submit Review</.button>
            </.form>
          </div>
          <div class="space-y-4">
            <%= for r <- @artisan_reviews do %>
              <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
                <div class="flex items-center gap-2 mb-1">
                  <div class="flex">
                    <%= for i <- 1..5 do %>
                      <svg class={"w-4 h-4 " <> if i <= r.rating, do: "text-yellow-400", else: "text-gray-300"} fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                      </svg>
                    <% end %>
                  </div>
                  <span class="text-xs text-gray-500"><%= Calendar.strftime(r.inserted_at, "%b %d, %Y") %></span>
                </div>
                <p class="text-sm text-gray-700"><%= r.comment %></p>
              </div>
            <% end %>
            <%= if @artisan_reviews == [] do %>
              <div class="text-gray-500">No reviews yet.</div>
            <% end %>
          </div>
        </div>
      </div>

      <.modal :if={@show_message_modal} id="message-artisan-modal" show on_cancel={JS.push("close_message_artisan")}>
        <div class="p-6 max-w-lg mx-auto">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-gray-900">Message Artisan</h3>
            <button phx-click="close_message_artisan" class="text-gray-400 hover:text-gray-600">✕</button>
          </div>
          <%= if @current_user do %>
            <.form for={@message_form} phx-submit="send_message_artisan" class="space-y-4">
              <.input field={@message_form[:subject]} type="text" label="Subject" required />
              <.input field={@message_form[:body]} type="textarea" label="Message" required />
              <div>
                <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white">Send Message</.button>
              </div>
            </.form>
          <% else %>
            <p class="text-gray-700">Please <.link navigate={~p"/users/log_in"} class="text-indigo-600 hover:text-indigo-700 font-medium">log in</.link> to send a message to this artisan.</p>
          <% end %>
        </div>
      </.modal>
    </div>
    """
  end
end
