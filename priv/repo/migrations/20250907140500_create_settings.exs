defmodule HandmadeHub.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :key, :string, null: false
      add :value, :string
      add :data_type, :string, null: false, default: "string" # string, boolean, integer, json

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:key])
  end
end
