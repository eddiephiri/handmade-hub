defmodule HandmadeHub.Repo.Migrations.CreateArtisanPayouts do
  use Ecto.Migration

  def change do
    create table(:artisan_payouts) do
      add :artisan_id, references(:users, on_delete: :delete_all), null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "ZMW", null: false
      add :status, :string, null: false, default: "pending" # pending, processing, completed, failed
      add :scheduled_date, :utc_datetime
      add :completed_at, :utc_datetime
      add :payment_period, :string # e.g., "2025-01-01 to 2025-01-07"
      add :order_ids, {:array, :integer}, default: []
      add :transaction_count, :integer, default: 0
      add :platform_fee, :decimal, precision: 10, scale: 2, default: 0
      add :net_amount, :decimal, precision: 10, scale: 2 # amount after platform fee
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:artisan_payouts, [:artisan_id])
    create index(:artisan_payouts, [:status])
    create index(:artisan_payouts, [:scheduled_date])

    # Add foreign key constraint to pawapay_transactions.payout_id now that artisan_payouts exists
    alter table(:pawapay_transactions) do
      modify :payout_id, references(:artisan_payouts, on_delete: :nilify_all)
    end
  end
end
