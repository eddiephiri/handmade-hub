defmodule HandmadeHub.Orders.Dispute do
  use Ecto.Schema
  import Ecto.Changeset

  alias HandmadeHub.Orders.Order
  alias HandmadeHub.Accounts.User

  schema "disputes" do
    belongs_to :order, Order
    belongs_to :opened_by_user, User
    field :status, :string, default: "open"
    field :reason, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(dispute, attrs) do
    dispute
    |> cast(attrs, [:order_id, :opened_by_user_id, :status, :reason, :notes])
    |> validate_required([:order_id, :status])
    |> validate_inclusion(:status, ["open", "resolved", "closed"])
  end
end
