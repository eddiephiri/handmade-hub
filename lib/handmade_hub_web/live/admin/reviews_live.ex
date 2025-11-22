defmodule HandmadeHubWeb.Admin.ReviewsLive do
  use HandmadeHubWeb, :live_view
  alias HandmadeHub.{Reviews, Audit}
  alias HandmadeHub.Reviews.Review
  import Ecto.Query
  alias HandmadeHub.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, search: "", visibility: "all", flagged: "all", reviews: list_reviews(%{}), confirming_action: nil)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q, reviews: list_reviews(%{search: q, visibility: socket.assigns.visibility, flagged: socket.assigns.flagged}))}
  end

  def handle_event("filter", %{"visibility" => visibility, "flagged" => flagged}, socket) do
    {:noreply, assign(socket, visibility: visibility, flagged: flagged, reviews: list_reviews(%{search: socket.assigns.search, visibility: visibility, flagged: flagged}))}
  end

  def handle_event("toggle_visible", %{"id" => id, "visible" => visible}, socket) do
    review = Repo.get!(Review, id)
    {:ok, _} = review |> Review.changeset(%{visible: visible == "true"}) |> Repo.update()
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: review.user_id, action: "review_visibility_updated", metadata: %{review_id: review.id, visible: visible})
    {:noreply, assign(socket, reviews: list_reviews(%{search: socket.assigns.search, visibility: socket.assigns.visibility, flagged: socket.assigns.flagged}))}
  end

  def handle_event("toggle_flag", %{"id" => id, "flagged" => flagged}, socket) do
    review = Repo.get!(Review, id)
    {:ok, _} = review |> Review.changeset(%{flagged: flagged == "true"}) |> Repo.update()
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: review.user_id, action: "review_flag_updated", metadata: %{review_id: review.id, flagged: flagged})
    {:noreply, assign(socket, reviews: list_reviews(%{search: socket.assigns.search, visibility: socket.assigns.visibility, flagged: socket.assigns.flagged}))}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirming_action: %{action: "delete", id: id})}
  end

  def handle_event("clear_confirmation", _params, socket) do
    {:noreply, assign(socket, confirming_action: nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    review = Repo.get!(Review, id)
    {:ok, _} = Repo.delete(review)
    _ = Audit.log_admin_action(admin_id: (socket.assigns[:current_admin] && socket.assigns.current_admin.id), target_user_id: review.user_id, action: "review_deleted", metadata: %{review_id: review.id})
    {:noreply, assign(socket, reviews: list_reviews(%{search: socket.assigns.search, visibility: socket.assigns.visibility, flagged: socket.assigns.flagged}), confirming_action: nil)}
  end

  defp list_reviews(%{search: search, visibility: visibility, flagged: flagged}) do
    query = from r in Review, preload: [:user]
    query =
      case visibility do
        "visible" -> where(query, [r], r.visible == true)
        "hidden" -> where(query, [r], r.visible == false)
        _ -> query
      end
    query =
      case flagged do
        "flagged" -> where(query, [r], r.flagged == true)
        "unflagged" -> where(query, [r], r.flagged == false)
        _ -> query
      end
    query =
      if search && String.trim(search) != "" do
        like = "%#{search}%"
        where(query, [r], ilike(r.comment, ^like))
      else
        query
      end
    Repo.all(order_by(query, [r], desc: r.inserted_at))
  end
  defp list_reviews(_), do: list_reviews(%{search: "", visibility: "all", flagged: "all"})
end
