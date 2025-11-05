defmodule HandmadeHub.Repo.Migrations.AddDeliveryAssignmentToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :delivery_assignment_id, references(:delivery_assignments, on_delete: :nilify_all)
    end

    create index(:orders, [:delivery_assignment_id])
  end
end
