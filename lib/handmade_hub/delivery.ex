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
  Assigns an order to a rider.
  """
  def assign_order_to_rider(order_id, rider_id, admin_id) do
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
        assignment = if assignment.order do
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
        updated_assignment = if updated_assignment.order do
          %{updated_assignment | order: Repo.preload(updated_assignment.order, [:shipping_address])}
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
end
