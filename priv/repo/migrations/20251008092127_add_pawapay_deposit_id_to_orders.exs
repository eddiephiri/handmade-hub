defmodule HandmadeHub.Repo.Migrations.AddPawapayDepositIdToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :pawapay_deposit_id, :string
    end

    create index(:orders, [:pawapay_deposit_id])
  end
end
