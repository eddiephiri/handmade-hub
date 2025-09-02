defmodule HandmadeHub.Orders.ShippingAddress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shipping_addresses" do
    field :recipient_name, :string
    field :phone_number, :string
    field :address_line_1, :string
    field :address_line_2, :string
    field :city, :string
    field :province, :string
    field :postal_code, :string
    field :country, :string, default: "Zambia"
    field :delivery_instructions, :string
    
    belongs_to :order, HandmadeHub.Orders.Order
    
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(shipping_address, attrs) do
    shipping_address
    |> cast(attrs, [
      :order_id, :recipient_name, :phone_number, 
      :address_line_1, :address_line_2, :city, 
      :province, :postal_code, :country, :delivery_instructions
    ])
    |> validate_required([:recipient_name, :phone_number, :address_line_1, :city])
    |> validate_format(:phone_number, ~r/^(0|260)\d{9}$/, message: "Invalid phone number format")
    |> validate_length(:recipient_name, min: 2, max: 100)
    |> validate_length(:address_line_1, min: 5, max: 200)
    |> validate_length(:city, min: 2, max: 100)
  end

  @doc """
  List of Zambian provinces for dropdown selection
  """
  def provinces do
    [
      "Central",
      "Copperbelt", 
      "Eastern",
      "Luapula",
      "Lusaka",
      "Muchinga",
      "Northern",
      "North-Western",
      "Southern",
      "Western"
    ]
  end

  @doc """
  Common cities in Zambia for autocomplete
  """
  def common_cities do
    [
      "Lusaka",
      "Kitwe",
      "Ndola",
      "Kabwe",
      "Chingola",
      "Mufulira",
      "Livingstone",
      "Luanshya",
      "Kasama",
      "Chipata",
      "Kalulushi",
      "Mazabuka",
      "Solwezi",
      "Chililabombwe",
      "Mongu",
      "Kafue"
    ]
  end
end
