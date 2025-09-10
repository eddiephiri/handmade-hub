defmodule HandmadeHubWeb.MessagesLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.{Accounts, Messaging}

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    other_id = params["with"] && String.to_integer(params["with"])
    conversations = Messaging.list_conversations(user.id)
    origin = params["from"]
    show_artisan_sidebar = user.role == "artisan" and user.artisan_status == "approved"
    back_to = case origin do
      "browse" -> ~p"/browse"
      "dashboard" -> ~p"/artisan/dashboard"
      _ -> ~p"/buyer/dashboard"
    end

    socket = assign(socket,
      page_title: "Messages",
      conversations: conversations,
      with_user: (other_id && Accounts.get_user!(other_id)),
      messages: (other_id && Messaging.list_messages(user.id, other_id)) || [],
      message_form: to_form(%{}, as: :message),
      back_to: back_to
    )
    |> assign(:show_artisan_sidebar, true)
    |> assign(:hide_back_to_browse, true)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_conversation", %{"other_id" => other_id}, socket) do
    other_id = String.to_integer(other_id)
    Messaging.mark_read(socket.assigns.current_user.id, other_id)
    {:noreply, assign(socket, with_user: Accounts.get_user!(other_id), messages: Messaging.list_messages(socket.assigns.current_user.id, other_id))}
  end

  def handle_event("send", %{"message" => %{"body" => body}}, socket) do
    if socket.assigns.with_user do
      {:ok, _} = Messaging.send_message(%{
        sender_id: socket.assigns.current_user.id,
        recipient_id: socket.assigns.with_user.id,
        subject: nil,
        body: body
      })
      {:noreply, assign(socket, messages: Messaging.list_messages(socket.assigns.current_user.id, socket.assigns.with_user.id), message_form: to_form(%{}, as: :message))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-3">
      <.link navigate={@back_to} class="inline-flex items-center text-indigo-600 hover:text-indigo-700">
        <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back
      </.link>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <h2 class="text-lg font-semibold mb-4">Conversations</h2>
        <div class="space-y-2">
          <%= for convo <- @conversations do %>
            <button phx-click="select_conversation" phx-value-other_id={convo.other_id} class={["w-full text-left p-3 rounded-lg hover:bg-gray-50", @with_user && @with_user.id == convo.other_id && "bg-indigo-50"]}>
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-full bg-indigo-600 text-white flex items-center justify-center text-sm font-bold">
                  <%= convo.last_message.sender_id == convo.other_id && "T" || "Y" %>
                </div>
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-900">
                    <%= Accounts.get_user!(convo.other_id).name || Accounts.get_user!(convo.other_id).email %>
                  </p>
                  <p class="text-xs text-gray-500 truncate"><%= convo.last_message.body %></p>
                </div>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <div class="md:col-span-2 bg-white rounded-xl border border-gray-100 p-4 flex flex-col min-h-[24rem]">
        <%= if @with_user do %>
          <div class="border-b pb-3 mb-3">
            <h3 class="font-semibold text-gray-900"><%= @with_user.name || @with_user.email %></h3>
          </div>
          <div id="messages" class="flex-1 space-y-3 overflow-y-auto">
            <%= for msg <- @messages do %>
              <div class={["max-w-[75%] p-3 rounded-lg", msg.sender_id == @current_user.id && "bg-indigo-600 text-white ml-auto" || "bg-gray-100 text-gray-900"]}>
                <p class="text-sm whitespace-pre-line"><%= msg.body %></p>
                <p class="text-[11px] opacity-70 mt-1"><%= Calendar.strftime(msg.inserted_at, "%b %d, %I:%M %p") %></p>
              </div>
            <% end %>
          </div>
          <div class="mt-4">
            <.form for={@message_form} phx-submit="send" class="flex gap-2">
              <.input field={@message_form[:body]} type="textarea" placeholder="Type a message..." class="flex-1" />
              <.button type="submit" class="bg-indigo-600 hover:bg-indigo-700 text-white">Send</.button>
            </.form>
          </div>
        <% else %>
          <div class="h-full flex items-center justify-center text-gray-500">Select a conversation</div>
        <% end %>
      </div>
    </div>
    """
  end
end
