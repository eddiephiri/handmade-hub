defmodule HandmadeHub.Payments.PawapayTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias HandmadeHub.Orders.Order
  alias HandmadeHub.Payments.ArtisanPayout
  alias HandmadeHub.Accounts.User

  schema "pawapay_transactions" do
    field :transaction_id, :string
    field :transaction_type, :string
    field :status, :string, default: "pending"
    field :amount, :decimal
    field :currency, :string, default: "ZMW"
    field :callback_data, :map
    field :error_message, :string
    field :provider_response, :string

    belongs_to :order, Order
    belongs_to :payout, ArtisanPayout
    belongs_to :artisan, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :transaction_id,
      :transaction_type,
      :status,
      :amount,
      :currency,
      :order_id,
      :payout_id,
      :artisan_id,
      :callback_data,
      :error_message,
      :provider_response
    ])
    |> validate_required([:transaction_id, :transaction_type, :status, :amount, :currency])
    |> validate_inclusion(:transaction_type, ~w(deposit payout refund))
    |> validate_inclusion(:status, ~w(pending completed failed cancelled))
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:transaction_id)
  end
end
