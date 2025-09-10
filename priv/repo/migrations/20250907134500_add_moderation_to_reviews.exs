defmodule HandmadeHub.Repo.Migrations.AddModerationToReviews do
  use Ecto.Migration

  def change do
    alter table(:reviews) do
      add :visible, :boolean, null: false, default: true
      add :flagged, :boolean, null: false, default: false
    end

    create index(:reviews, [:visible])
    create index(:reviews, [:flagged])
  end
end
