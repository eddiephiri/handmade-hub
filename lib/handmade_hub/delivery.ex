defmodule HandmadeHub.Delivery do
  @moduledoc """
  Context for managing delivery riders and assignments.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Delivery.{Rider, Assignment}
  alias HandmadeHub.DeliveryNotifier

  ## Riders

  @doc """
  Returns the list of riders.
  """
  def list_riders do
    Repo.all(Rider)
  end

  @doc """
  Returns the list of active riders.
  """
  def list_active_riders do
    Rider
    |> where([r], r.status == "active")
    |> order_by([r], asc: r.name)
    |> Repo.all()
  end

  @doc """
  Gets a single rider.
  """
  def get_rider!(id) do
    Rider
    |> Repo.get!(id)
    |> Repo.preload(:assignments)
  end

  @doc """
  Creates a rider.
  """
  def create_rider(attrs \\ %{}) do
    %Rider{}
    |> Rider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rider.
  """
  def update_rider(%Rider{} = rider, attrs) do
    rider
    |> Rider.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a rider.
  """
  def delete_rider(%Rider{} = rider) do
    Repo.delete(rider)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rider changes.
  """
  def change_rider(%Rider{} = rider, attrs \\ %{}) do
    Rider.changeset(rider, attrs)
  end

  ## Assignments

  @doc """
  Returns the list of assignments.
  """
  def list_assignments do
    Assignment
    |> Repo.all()
    |> Repo.preload([:order, :rider, :assigned_by_admin])
  end

  @doc """
  Returns assignment records for the admin deliveries view with eager-loaded details.

  Accepts optional filters via a map:

    * `:status` - filters by assignment status
    * `:search` - performs an ilike search across assignment id, order/customer fields, and rider name/phone
  """
  def list_assignments_admin(opts \\ %{}) do
    assignment_with_details_query()
    |> apply_status_filter(Map.get(opts, :status))
    |> apply_search(Map.get(opts, :search))
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Fetches a single assignment with associated order, rider, and admin details preloaded.
  """
  def get_assignment_with_details!(id) do
    assignment_with_details_query()
    |> where([a], a.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Gets an assignment by order_id.
  """
  def get_assignment_by_order_id(order_id) do
    Assignment
    |> where([a], a.order_id == ^order_id)
    |> Repo.one()
    |> Repo.preload([:order, :rider, :assigned_by_admin])
  end

  @doc """
  Gets a single assignment.
  """
  def get_assignment!(id) do
    Assignment
    |> Repo.get!(id)
    |> Repo.preload([:order, :rider, :assigned_by_admin])
  end

  @doc """
  Assigns an order to a rider. If an assignment already exists, updates it (reassignment).
  """
  def assign_order_to_rider(order_id, rider_id, admin_id) do
    case get_assignment_by_order_id(order_id) do
      nil ->
        # No existing assignment, create new one
        case %Assignment{}
             |> Assignment.changeset(%{
               order_id: order_id,
               rider_id: rider_id,
               assigned_by_admin_id: admin_id,
               status: "dispatched"
             })
             |> Repo.insert() do
          {:ok, assignment} ->
            assignment = Repo.preload(assignment, [:order, :rider, :assigned_by_admin])

            # Preload shipping address if order exists
            assignment =
              if assignment.order do
                %{assignment | order: Repo.preload(assignment.order, [:shipping_address])}
              else
                assignment
              end

            # Send email to rider
            DeliveryNotifier.deliver_assignment_notification(assignment)

            {:ok, assignment}

          error ->
            error
        end

      existing_assignment ->
        # Assignment exists, update it (reassignment)
        case update_assignment(existing_assignment, %{
               rider_id: rider_id,
               assigned_by_admin_id: admin_id,
               status: "dispatched"
             }) do
          {:ok, updated_assignment} ->
            updated_assignment =
              Repo.preload(updated_assignment, [:order, :rider, :assigned_by_admin])

            # Preload shipping address if order exists
            updated_assignment =
              if updated_assignment.order do
                %{
                  updated_assignment
                  | order: Repo.preload(updated_assignment.order, [:shipping_address])
                }
              else
                updated_assignment
              end

            # Send email to new rider about reassignment
            DeliveryNotifier.deliver_assignment_notification(updated_assignment)

            {:ok, updated_assignment}

          error ->
            error
        end
    end
  end

  @doc """
  Updates an assignment.
  """
  def update_assignment(%Assignment{} = assignment, attrs) do
    assignment
    |> Assignment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates assignment status and sends email if needed.
  """
  def update_assignment_status(assignment_id, status) do
    assignment = get_assignment!(assignment_id)

    case update_assignment(assignment, %{status: status}) do
      {:ok, updated_assignment} ->
        updated_assignment = Repo.preload(updated_assignment, [:order, :rider])

        # Preload shipping address if order exists
        updated_assignment =
          if updated_assignment.order do
            %{
              updated_assignment
              | order: Repo.preload(updated_assignment.order, [:shipping_address])
            }
          else
            updated_assignment
          end

        # Send email notification based on status
        DeliveryNotifier.deliver_status_update(updated_assignment)

        {:ok, updated_assignment}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking assignment changes.
  """
  def change_assignment(%Assignment{} = assignment, attrs \\ %{}) do
    Assignment.changeset(assignment, attrs)
  end

  @doc """
  Derives a high-level delivery phase for a given order, based on its status
  and any associated delivery assignment.

  This is a read-only helper used by UIs and does not change simulator or
  backend behaviour.
  """
  def derive_delivery_phase(order) do
    assignment = Map.get(order, :delivery_assignment)

    cond do
      is_nil(assignment) and order.status in ["pending", "processing"] ->
        :preparing

      assignment && assignment.status == "dispatched" ->
        :dispatched

      assignment && assignment.status == "in_transit" ->
        :in_transit

      assignment && assignment.status == "failed" ->
        :failed

      order.status == "delivered" or (assignment && assignment.status == "delivered") ->
        :delivered

      true ->
        :unknown
    end
  end

  ## Auto-Assignment

  @doc """
  Automatically assigns a rider to an order using workload balancing.
  Selects the rider with the least active assignments.
  Returns {:ok, assignment} if successful, {:error, reason} otherwise.
  """
  def auto_assign_rider_to_order(order_id) do
    require Logger

    # Check if order already has an assignment
    case get_assignment_by_order_id(order_id) do
      nil ->
        # No assignment exists, proceed with auto-assignment
        do_auto_assign_rider(order_id)

      existing_assignment ->
        # Order already has a rider assigned
        Logger.info(
          "Order #{order_id} already has rider assigned: #{existing_assignment.rider_id}"
        )

        {:ok, existing_assignment}
    end
  end

  defp do_auto_assign_rider(order_id) do
    require Logger

    available_riders = list_active_riders()

    case available_riders do
      [] ->
        Logger.warning("No active riders available for auto-assignment of order #{order_id}")
        notify_admin_no_riders(order_id)
        {:error, :no_riders_available}

      riders ->
        rider = select_best_rider(riders)
        system_admin_id = get_system_admin_id()

        case assign_order_to_rider(order_id, rider.id, system_admin_id) do
          {:ok, assignment} ->
            Logger.info("Auto-assigned rider #{rider.id} to order #{order_id}")
            {:ok, assignment}

          {:error, %Ecto.Changeset{errors: errors}} ->
            # Check if it's a unique constraint error (already assigned)
            if Keyword.has_key?(errors, :order_id) do
              # Order already assigned (race condition)
              case get_assignment_by_order_id(order_id) do
                nil ->
                  Logger.error(
                    "Failed to auto-assign rider to order #{order_id}: #{inspect(errors)}"
                  )

                  notify_admin_assignment_failed(order_id, inspect(errors))
                  {:error, :assignment_failed}

                assignment ->
                  {:ok, assignment}
              end
            else
              Logger.error("Failed to auto-assign rider to order #{order_id}: #{inspect(errors)}")
              notify_admin_assignment_failed(order_id, inspect(errors))
              {:error, :assignment_failed}
            end

          error ->
            Logger.error("Failed to auto-assign rider to order #{order_id}: #{inspect(error)}")
            notify_admin_assignment_failed(order_id, inspect(error))
            error
        end
    end
  end

  @doc """
  Selects the best rider based on current workload (least active assignments).
  """
  def select_best_rider(riders) when is_list(riders) do
    riders_with_counts =
      Enum.map(riders, fn rider ->
        count = count_active_assignments(rider.id)
        {rider, count}
      end)

    # Sort by assignment count (ascending) and pick first
    riders_with_counts
    |> Enum.sort_by(fn {_rider, count} -> count end)
    |> List.first()
    |> elem(0)
  end

  @doc """
  Counts active assignments (dispatched or in_transit) for a rider.
  """
  def count_active_assignments(rider_id) do
    Assignment
    |> where([a], a.rider_id == ^rider_id)
    |> where([a], a.status in ["dispatched", "in_transit"])
    |> Repo.aggregate(:count, :id)
  end

  defp get_system_admin_id do
    # Get first super_admin for system assignments
    admins = HandmadeHub.Admins.list_admins()
    super_admin = Enum.find(admins, fn a -> a.role == "super_admin" end)
    if super_admin, do: super_admin.id, else: nil
  end

  defp notify_admin_no_riders(order_id) do
    require Logger
    alias HandmadeHub.Notifications

    # Get all super admins
    admins = HandmadeHub.Admins.list_admins() |> Enum.filter(fn a -> a.role == "super_admin" end)

    Enum.each(admins, fn admin ->
      _ =
        Notifications.enqueue_email(%{
          to: admin.email,
          subject: "⚠️ No Riders Available for Order Assignment",
          text_body: """
          ==============================

          Warning: Order Assignment Failed

          Order ID: #{order_id}
          Reason: No active riders available

          Please add active riders or manually assign a rider to this order.

          Admin Panel: /admin/orders

          ==============================
          """,
          type: "admin_notification",
          scheduled_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
    end)

    Logger.warning("Notified admins about missing riders for order #{order_id}")
  end

  defp notify_admin_assignment_failed(order_id, error_details) do
    require Logger
    alias HandmadeHub.Notifications

    # Get all super admins
    admins = HandmadeHub.Admins.list_admins() |> Enum.filter(fn a -> a.role == "super_admin" end)

    Enum.each(admins, fn admin ->
      _ =
        Notifications.enqueue_email(%{
          to: admin.email,
          subject: "⚠️ Failed to Auto-Assign Rider to Order",
          text_body: """
          ==============================

          Warning: Automatic Rider Assignment Failed

          Order ID: #{order_id}
          Error: #{error_details}

          Please manually assign a rider to this order.

          Admin Panel: /admin/orders

          ==============================
          """,
          type: "admin_notification",
          scheduled_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
    end)

    Logger.warning(
      "Notified admins about assignment failure for order #{order_id}: #{error_details}"
    )
  end

  defp assignment_with_details_query do
    from a in Assignment,
      left_join: o in assoc(a, :order),
      left_join: u in assoc(o, :user),
      left_join: sa in assoc(o, :shipping_address),
      left_join: r in assoc(a, :rider),
      left_join: admin in assoc(a, :assigned_by_admin),
      preload: [
        order: {o, [user: u, shipping_address: sa]},
        rider: r,
        assigned_by_admin: admin
      ]
  end

  defp apply_status_filter(query, status) when status in [nil, ""], do: query

  defp apply_status_filter(query, status) do
    where(query, [a], a.status == ^status)
  end

  defp apply_search(query, search) when search in [nil, ""], do: query

  defp apply_search(query, search) do
    term =
      search
      |> String.trim()

    if term == "" do
      query
    else
      like = "%#{term}%"

      from [a, o, u, _sa, r, admin] in query,
        where:
          ilike(fragment("CAST(? AS TEXT)", a.id), ^like) or
            ilike(coalesce(o.order_number, ""), ^like) or
            ilike(coalesce(o.customer_name, ""), ^like) or
            ilike(coalesce(o.customer_email, ""), ^like) or
            ilike(coalesce(o.customer_phone, ""), ^like) or
            ilike(coalesce(r.name, ""), ^like) or
            ilike(coalesce(r.phone_number, ""), ^like) or
            ilike(coalesce(u.name, ""), ^like) or
            ilike(coalesce(u.email, ""), ^like) or
            ilike(coalesce(admin.username, ""), ^like)
    end
  end
end
