defmodule HandmadeHub.Repo.Migrations.CreatePayoutSettings do
  use Ecto.Migration

  def change do
    create table(:payout_settings) do
      add :schedule_type, :string, null: false, default: "weekly" # weekly, monthly
      add :schedule_day, :integer, default: 1 # 1-7 for weekly (1=Monday), 1-31 for monthly
      add :minimum_payout_amount, :decimal, precision: 10, scale: 2, default: 50.00
      add :platform_fee_percentage, :decimal, precision: 5, scale: 2, default: 10.00
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end
  end
end
