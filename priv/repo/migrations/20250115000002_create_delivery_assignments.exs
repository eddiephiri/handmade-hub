defmodule HandmadeHub.Repo.Migrations.CreateDeliveryAssignments do
  use Ecto.Migration

  def up do
    # Create table only if it doesn't exist
    execute("""
      CREATE TABLE IF NOT EXISTS delivery_assignments (
        id BIGSERIAL PRIMARY KEY,
        order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE SET NULL,
        rider_id BIGINT NOT NULL REFERENCES delivery_riders(id) ON DELETE SET NULL,
        assigned_by_admin_id BIGINT REFERENCES admins(id) ON DELETE SET NULL,
        status VARCHAR(255) DEFAULT 'dispatched',
        notes TEXT,
        inserted_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      )
    """)

    # Create unique index on order_id (only if it doesn't exist)
    # Note: unique_index already creates an index, so we don't need a separate index on order_id
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS delivery_assignments_order_id_index
      ON delivery_assignments (order_id)
    """)

    execute("""
      CREATE INDEX IF NOT EXISTS delivery_assignments_rider_id_index
      ON delivery_assignments (rider_id)
    """)

    execute("""
      CREATE INDEX IF NOT EXISTS delivery_assignments_status_index
      ON delivery_assignments (status)
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS delivery_assignments")
  end
end
