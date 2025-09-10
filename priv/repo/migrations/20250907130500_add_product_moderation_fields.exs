defmodule HandmadeHub.Repo.Migrations.AddProductModerationFields do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :approval_status, :string, null: false, default: "pending"
      add :removed_at, :utc_datetime
    end

    create index(:products, [:approval_status])
    create index(:products, [:category])
    create index(:products, [:inserted_at])
  end
end
