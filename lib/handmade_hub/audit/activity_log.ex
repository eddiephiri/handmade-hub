defmodule HandmadeHub.Audit.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias HandmadeHub.Admins.Admin
  alias HandmadeHub.Accounts.User

  schema "activity_logs" do
    belongs_to :admin, Admin
    belongs_to :target_user, User
    field :action, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t, map) :: Ecto.Changeset.t() when t: %__MODULE__{}
  def changeset(activity_log, attrs) do
    activity_log
    |> cast(attrs, [:admin_id, :target_user_id, :action, :metadata])
    |> validate_required([:action])
  end
end
