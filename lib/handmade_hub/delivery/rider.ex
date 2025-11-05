defmodule HandmadeHub.Delivery.Rider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "delivery_riders" do
    field :name, :string
    field :phone_number, :string
    field :status, :string, default: "active"
    field :vehicle_type, :string, default: "motorbike"

    has_many :assignments, HandmadeHub.Delivery.Assignment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rider, attrs) do
    rider
    |> cast(attrs, [:name, :phone_number, :status, :vehicle_type])
    |> validate_required([:name, :phone_number])
    |> validate_inclusion(:status, ~w(active inactive suspended))
    |> validate_format(:phone_number, ~r/^(0|260)\d{9}$/, message: "Invalid phone number format")
    |> unique_constraint(:phone_number)
  end
end
