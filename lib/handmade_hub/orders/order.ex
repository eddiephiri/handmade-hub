defmodule HandmadeHub.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :order_number, :string
    field :status, :string, default: "pending"
    field :payment_status, :string, default: "pending"
    field :payment_method, :string
    field :subtotal, :decimal
    field :shipping_fee, :decimal, default: Decimal.new("0")
    field :total, :decimal
    field :notes, :string

    # Customer info (for guest checkout)
    field :customer_email, :string
    field :customer_phone, :string
    field :customer_name, :string

    # Payment details
    field :payment_reference, :string
    field :mobile_money_provider, :string
    field :mobile_money_number, :string
    field :pawapay_deposit_id, :string

    belongs_to :user, HandmadeHub.Accounts.User
    has_many :order_items, HandmadeHub.Orders.OrderItem
    has_one :shipping_address, HandmadeHub.Orders.ShippingAddress

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :user_id, :order_number, :status, :payment_status, :payment_method,
      :subtotal, :shipping_fee, :total, :notes,
      :customer_email, :customer_phone, :customer_name,
      :payment_reference, :mobile_money_provider, :mobile_money_number, :pawapay_deposit_id
    ])
    |> validate_required([:order_number, :subtotal, :total])
    |> validate_inclusion(:status, ~w(pending processing shipped delivered cancelled))
    |> validate_inclusion(:payment_status, ~w(pending paid failed refunded))
    |> validate_inclusion(:payment_method, ~w(mobile_money card cash_on_delivery), message: "Invalid payment method")
    |> validate_inclusion(:mobile_money_provider, ~w(mtn airtel zamtel), message: "Invalid mobile money provider", allow_nil: true)
    |> validate_format(:customer_email, ~r/^[^\s]+@[^\s]+$/, message: "Invalid email format", allow_blank: true)
    |> validate_format(:customer_phone, ~r/^(0|260)\d{9}$/, message: "Invalid phone number format", allow_blank: true)
    |> unique_constraint(:order_number)
  end

  @doc """
  Generates a unique order number
  """
  def generate_order_number do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :crypto.strong_rand_bytes(3) |> Base.encode16()
    "ORD-#{timestamp}-#{random}"
  end

  @doc """
  Calculates total from subtotal and shipping fee
  """
  def calculate_total(subtotal, shipping_fee) do
    Decimal.add(subtotal || Decimal.new("0"), shipping_fee || Decimal.new("0"))
  end
end
