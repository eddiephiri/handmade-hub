defmodule HandmadeHub.Repo.Migrations.CreatePawapayTransactions do
  use Ecto.Migration

  def change do
    create table(:pawapay_transactions) do
      add :transaction_id, :string, null: false
      add :transaction_type, :string, null: false # deposit, payout, refund
      add :status, :string, null: false, default: "pending" # pending, completed, failed, cancelled
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "ZMW", null: false

      # References
      add :order_id, references(:orders, on_delete: :nilify_all)
      add :payout_id, :integer # Will be added as foreign key after artisan_payouts table is created
      add :artisan_id, references(:users, on_delete: :nilify_all)

      # Data storage
      add :callback_data, :map # jsonb for storing raw callback
      add :error_message, :text
      add :provider_response, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pawapay_transactions, [:transaction_id])
    create index(:pawapay_transactions, [:transaction_type])
    create index(:pawapay_transactions, [:status])
    create index(:pawapay_transactions, [:order_id])
    create index(:pawapay_transactions, [:payout_id])
    create index(:pawapay_transactions, [:artisan_id])
  end
end
