defmodule HandmadeHub.Repo.Migrations.CreateDisputes do
  use Ecto.Migration

  def change do
    create table(:disputes) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :opened_by_user_id, references(:users, on_delete: :nilify_all)
      add :status, :string, null: false, default: "open" # open, resolved, closed
      add :reason, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:disputes, [:order_id])
    create index(:disputes, [:status])
  end
end
