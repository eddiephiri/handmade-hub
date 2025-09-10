defmodule HandmadeHub.Settings.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :key, :string
    field :value, :string
    field :data_type, :string, default: "string"

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :data_type])
    |> validate_required([:key, :data_type])
    |> unique_constraint(:key)
  end
end
