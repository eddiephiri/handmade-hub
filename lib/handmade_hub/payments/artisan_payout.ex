defmodule HandmadeHub.Payments.ArtisanPayout do
  use Ecto.Schema
  import Ecto.Changeset

  alias HandmadeHub.Accounts.User
  alias HandmadeHub.Payments.PawapayTransaction

  schema "artisan_payouts" do
    field :amount, :decimal
    field :currency, :string, default: "ZMW"
    field :status, :string, default: "pending"
    field :scheduled_date, :utc_datetime
    field :completed_at, :utc_datetime
    field :payment_period, :string
    field :order_ids, {:array, :integer}, default: []
    field :transaction_count, :integer, default: 0
    field :platform_fee, :decimal
    field :net_amount, :decimal
    field :notes, :string

    belongs_to :artisan, User
    has_many :transactions, PawapayTransaction, foreign_key: :payout_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payout, attrs) do
    payout
    |> cast(attrs, [
      :artisan_id,
      :amount,
      :currency,
      :status,
      :scheduled_date,
      :completed_at,
      :payment_period,
      :order_ids,
      :transaction_count,
      :platform_fee,
      :net_amount,
      :notes
    ])
    |> validate_required([:artisan_id, :amount, :currency, :status])
    |> validate_inclusion(:status, ~w(pending processing completed failed))
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_number(:platform_fee, greater_than_or_equal_to: 0)
    |> validate_number(:net_amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:artisan_id)
  end
end
