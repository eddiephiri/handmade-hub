defmodule HandmadeHubWeb.UserSettingsLive do
  use HandmadeHubWeb, :live_view

  alias HandmadeHub.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-full">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <.link
          navigate={~p"/artisan/dashboard"}
          class="inline-flex items-center text-indigo-600 hover:text-indigo-700"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
          Back
        </.link>
        <!-- Header Section -->
        <div class="mb-8">
          <div class="flex items-center space-x-3 mb-2">
            <div class="p-3 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl shadow-lg">
              <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Account Settings</h1>
              <p class="text-gray-600 mt-1">Manage your account security and preferences</p>
            </div>
          </div>
        </div>

        <!-- User Info Card -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 mb-8">
          <div class="flex items-center space-x-4">
            <div class="relative">
              <%= if @current_user.profile_image do %>
                <img
                  src={@current_user.profile_image}
                  alt="Profile"
                  class="w-20 h-20 rounded-full object-cover border-4 border-white shadow-lg"
                />
              <% else %>
                <div class="w-20 h-20 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-2xl font-bold shadow-lg">
                  <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
                </div>
              <% end %>
              <div class="absolute bottom-0 right-0 w-6 h-6 bg-green-500 border-3 border-white rounded-full"></div>
            </div>
            <div class="flex-1">
              <h2 class="text-xl font-semibold text-gray-900">
                <%= @current_user.name || "User" %>
              </h2>
              <p class="text-gray-600 flex items-center mt-1">
                <svg class="w-4 h-4 mr-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                <%= @current_email %>
              </p>
              <p class="text-sm text-gray-500 mt-1">
                Account Type: <span class="font-medium text-indigo-600 capitalize"><%= @current_user.role || "Buyer" %></span>
              </p>
            </div>
          </div>
        </div>

        <!-- Settings Sections -->
        <div class="space-y-6">
          <!-- Email Settings Card -->
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
            <div class="bg-gradient-to-r from-blue-50 to-indigo-50 px-6 py-4 border-b border-gray-200">
              <div class="flex items-center">
                <svg class="w-5 h-5 text-indigo-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
                </svg>
                <h3 class="text-lg font-semibold text-gray-900">Email Address</h3>
              </div>
              <p class="text-sm text-gray-600 mt-1 ml-8">Update your email address for account notifications</p>
            </div>

            <div class="p-6">
              <.form
                for={@email_form}
                id="email_form"
                phx-submit="update_email"
                phx-change="validate_email"
                autocomplete="off"
                class="space-y-5"
              >
                <!-- Autofill decoys to discourage password managers from filling the real fields -->
                <input type="text" name="fake_username" autocomplete="username" tabindex="-1" style="position:absolute; left:-10000px; top:auto; width:1px; height:1px; overflow:hidden;" />
                <input type="password" name="fake_password" autocomplete="new-password" tabindex="-1" style="position:absolute; left:-10000px; top:auto; width:1px; height:1px; overflow:hidden;" />
                <div>
                  <label for={@email_form[:email].id} class="block text-sm font-medium text-gray-700 mb-2">
                    New Email Address
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                      </svg>
                    </div>
                    <.input
                      field={@email_form[:email]}
                      type="email"
                      required
                      autocomplete="email"
                      placeholder="Enter your new email"
                      class="pl-10 block w-full rounded-lg border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                </div>

                <div>
                  <label for="current_password_for_email" class="block text-sm font-medium text-gray-700 mb-2">
                    Current Password
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </div>
                    <.input
                      field={@email_form[:current_password]}
                      name="current_password"
                      id="current_password_for_email"
                      type="password"
                      required
                      placeholder="Enter your current password"
                      autocomplete="current-password"
                      inputmode="text"
                      class="pl-10 block w-full rounded-lg border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                </div>

                <div class="flex justify-end pt-4">
                  <button
                    type="submit"
                    phx-disable-with="Updating..."
                    class="inline-flex items-center px-6 py-3 border border-transparent text-sm font-medium rounded-lg shadow-sm text-white bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all duration-200"
                  >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    Update Email
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <!-- Password Settings Card -->
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
            <div class="bg-gradient-to-r from-purple-50 to-pink-50 px-6 py-4 border-b border-gray-200">
              <div class="flex items-center">
                <svg class="w-5 h-5 text-purple-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                </svg>
                <h3 class="text-lg font-semibold text-gray-900">Password</h3>
              </div>
              <p class="text-sm text-gray-600 mt-1 ml-8">Ensure your account stays secure with a strong password</p>
            </div>

            <div class="p-6">
              <.form
                for={@password_form}
                id="password_form"
                action={~p"/users/log_in?_action=password_updated"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-5"
              >
                <input
                  name={@password_form[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  value={@current_email}
                />

                <div>
                  <label for={@password_form[:password].id} class="block text-sm font-medium text-gray-700 mb-2">
                    New Password
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </div>
                    <.input
                      field={@password_form[:password]}
                      type="password"
                      required
                      autocomplete="new-password"
                      placeholder="Enter new password"
                      class="pl-10 block w-full rounded-lg border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                  <p class="mt-2 text-sm text-gray-500">Must be at least 12 characters long</p>
                </div>

                <div>
                  <label for={@password_form[:password_confirmation].id} class="block text-sm font-medium text-gray-700 mb-2">
                    Confirm New Password
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                      </svg>
                    </div>
                    <.input
                      field={@password_form[:password_confirmation]}
                      type="password"
                      autocomplete="new-password"
                      placeholder="Confirm new password"
                      class="pl-10 block w-full rounded-lg border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                </div>

                <div>
                  <label for="current_password_for_password" class="block text-sm font-medium text-gray-700 mb-2">
                    Current Password
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </div>
                    <.input
                      field={@password_form[:current_password]}
                      name="current_password"
                      type="password"
                      id="current_password_for_password"
                      required
                      autocomplete="current-password"
                      placeholder="Enter your current password"
                      class="pl-10 block w-full rounded-lg border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                </div>

                <div class="flex justify-end pt-4">
                  <button
                    type="submit"
                    phx-disable-with="Updating..."
                    class="inline-flex items-center px-6 py-3 border border-transparent text-sm font-medium rounded-lg shadow-sm text-white bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 transition-all duration-200"
                  >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                    </svg>
                    Update Password
                  </button>
                </div>
              </.form>
            </div>
          </div>

          <!-- Additional Settings Card -->
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
            <div class="bg-gradient-to-r from-green-50 to-teal-50 px-6 py-4 border-b border-gray-200">
              <div class="flex items-center">
                <svg class="w-5 h-5 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
                <h3 class="text-lg font-semibold text-gray-900">Security & Privacy</h3>
              </div>
              <p class="text-sm text-gray-600 mt-1 ml-8">Manage your account security preferences</p>
            </div>

            <div class="p-6 space-y-4">
              <div class="flex items-center justify-between py-3 border-b border-gray-100">
                <div>
                  <h4 class="text-sm font-medium text-gray-900">Two-Factor Authentication</h4>
                  <p class="text-sm text-gray-500 mt-1">Add an extra layer of security to your account</p>
                </div>
                <button class="px-4 py-2 text-sm font-medium text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors">
                  Enable
                </button>
              </div>

              <div class="flex items-center justify-between py-3 border-b border-gray-100">
                <div>
                  <h4 class="text-sm font-medium text-gray-900">Login History</h4>
                  <p class="text-sm text-gray-500 mt-1">View recent login activity</p>
                </div>
                <button phx-click="open_login_history" class="px-4 py-2 text-sm font-medium text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors">
                  View
                </button>
              </div>

              <div class="flex items-center justify-between py-3">
                <div>
                  <h4 class="text-sm font-medium text-gray-900">Delete Account</h4>
                  <p class="text-sm text-gray-500 mt-1">Permanently delete your account and all data</p>
                </div>
                <button phx-click="open_delete_account" class="px-4 py-2 text-sm font-medium text-red-600 bg-red-50 rounded-lg hover:bg-red-100 transition-colors">
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>

        <.modal :if={@show_login_history} id="login-history-modal" show on_cancel={JS.push("close_login_history")}>
          <div class="p-6 max-w-2xl mx-auto">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900">Recent Login Sessions</h3>
              <button phx-click="close_login_history" class="text-gray-400 hover:text-gray-600">
                ✕
              </button>
            </div>
            <div class="divide-y">
              <div :for={sess <- @login_sessions} class="py-3 flex items-center justify-between">
                <div class="text-sm text-gray-700">
                  <p>Session ID: <span class="font-mono text-gray-900"><%= Base.encode16(sess.token, case: :lower) |> String.slice(0, 12) %>…</span></p>
                  <p class="text-gray-500">Started: <%= Calendar.strftime(sess.inserted_at, "%b %d, %Y %I:%M %p") %></p>
                </div>
                <span class="text-xs px-2 py-1 rounded bg-gray-100 text-gray-700"><%= sess.context %></span>
              </div>
              <%= if @login_sessions == [] do %>
                <div class="py-6 text-center text-gray-500 text-sm">No recent sessions found.</div>
              <% end %>
            </div>
          </div>
        </.modal>
        <.modal :if={@show_delete_account} id="delete-account-modal" show on_cancel={JS.push("close_delete_account")}>
          <div class="p-6 max-w-md mx-auto">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Confirm Account Deletion</h3>
            <p class="text-sm text-gray-600 mb-4">This action is permanent and will remove your account and all associated data. Please confirm your password to continue.</p>
            <.form for={%{}} as={:confirm} phx-submit="confirm_delete_account" class="space-y-4">
              <div>
                <label for="confirm_current_password" class="block text-sm font-medium text-gray-700 mb-2">Current Password</label>
                <input id="confirm_current_password" name="current_password" type="password" required class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
              <div class="flex items-center justify-end gap-2">
                <button type="button" phx-click="close_delete_account" class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200">Cancel</button>
                <button type="submit" class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700">Delete Account</button>
              </div>
            </.form>
          </div>
        </.modal>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token} = _params, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    show_artisan_sidebar = user.role == "artisan" and user.artisan_status == "approved"
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:show_login_history, false)
      |> assign(:login_sessions, [])
      |> assign(:show_delete_account, false)
      |> assign(:show_artisan_sidebar, true)
      |> assign(:hide_back_to_browse, true)

    {:ok, socket}
  end

  def handle_event("validate_email", %{"user" => user_params}, socket) do
    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("open_login_history", _params, socket) do
    sessions = Accounts.list_user_login_sessions(socket.assigns.current_user, limit: 10)
    {:noreply, assign(socket, show_login_history: true, login_sessions: sessions)}
  end

  def handle_event("close_login_history", _params, socket) do
    {:noreply, assign(socket, show_login_history: false)}
  end

  def handle_event("open_delete_account", _params, socket) do
    {:noreply, assign(socket, show_delete_account: true)}
  end

  def handle_event("close_delete_account", _params, socket) do
    {:noreply, assign(socket, show_delete_account: false)}
  end

  def handle_event("confirm_delete_account", %{"current_password" => current_password}, socket) do
    user = socket.assigns.current_user
    case Accounts.delete_user(user, current_password) do
      {:ok, :deleted} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your account has been deleted.")
         |> redirect(to: ~p"/")}
      {:error, :invalid_password} ->
        {:noreply, put_flash(socket, :error, "Current password is invalid.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete account. Please try again.")}
    end
  end
end
