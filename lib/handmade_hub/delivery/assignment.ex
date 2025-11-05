defmodule HandmadeHub.Delivery.Assignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "delivery_assignments" do
    field :status, :string, default: "dispatched"
    field :notes, :string

    belongs_to :order, HandmadeHub.Orders.Order
    belongs_to :rider, HandmadeHub.Delivery.Rider
    belongs_to :assigned_by_admin, HandmadeHub.Admins.Admin, foreign_key: :assigned_by_admin_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:order_id, :rider_id, :assigned_by_admin_id, :status, :notes])
    |> validate_required([:order_id, :rider_id, :status])
    |> validate_inclusion(:status, ~w(dispatched in_transit delivered failed))
    |> unique_constraint(:order_id)
  end
end
