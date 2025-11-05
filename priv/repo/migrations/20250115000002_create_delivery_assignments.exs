defmodule HandmadeHub.Repo.Migrations.CreateDeliveryAssignments do
  use Ecto.Migration

  def change do
    create table(:delivery_assignments) do
      add :order_id, references(:orders, on_delete: :nilify_all), null: false
      add :rider_id, references(:delivery_riders, on_delete: :nilify_all), null: false
      add :assigned_by_admin_id, references(:admins, on_delete: :nilify_all)
      add :status, :string, default: "dispatched"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:delivery_assignments, [:order_id])
    create index(:delivery_assignments, [:rider_id])
    create index(:delivery_assignments, [:status])
    create unique_index(:delivery_assignments, [:order_id])
  end
end
