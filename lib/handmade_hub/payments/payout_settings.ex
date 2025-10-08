defmodule HandmadeHub.Payments.PayoutSettings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payout_settings" do
    field :schedule_type, :string, default: "weekly"
    field :schedule_day, :integer, default: 1
    field :minimum_payout_amount, :decimal
    field :platform_fee_percentage, :decimal
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [
      :schedule_type,
      :schedule_day,
      :minimum_payout_amount,
      :platform_fee_percentage,
      :is_active
    ])
    |> validate_required([:schedule_type, :schedule_day, :minimum_payout_amount, :platform_fee_percentage])
    |> validate_inclusion(:schedule_type, ~w(weekly monthly))
    |> validate_schedule_day()
    |> validate_number(:minimum_payout_amount, greater_than_or_equal_to: 0)
    |> validate_number(:platform_fee_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  defp validate_schedule_day(changeset) do
    schedule_type = get_field(changeset, :schedule_type)
    schedule_day = get_field(changeset, :schedule_day)

    case schedule_type do
      "weekly" ->
        validate_number(changeset, :schedule_day, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)

      "monthly" ->
        validate_number(changeset, :schedule_day, greater_than_or_equal_to: 1, less_than_or_equal_to: 31)

      _ ->
        changeset
    end
  end
end
