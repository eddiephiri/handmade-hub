defmodule HandmadeHub.Repo.Migrations.CreateDeliveryRiders do
  use Ecto.Migration

  def change do
    create table(:delivery_riders) do
      add :name, :string, null: false
      add :phone_number, :string, null: false
      add :status, :string, default: "active"
      add :vehicle_type, :string, default: "motorbike"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:delivery_riders, [:phone_number])
    create index(:delivery_riders, [:status])
  end
end
