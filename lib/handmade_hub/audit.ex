defmodule HandmadeHub.Audit do
  @moduledoc """
  Audit logging for admin actions.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Audit.ActivityLog

  @spec log_admin_action(keyword()) :: {:ok, ActivityLog.t()} | {:error, Ecto.Changeset.t()}
  def log_admin_action(attrs) when is_list(attrs) do
    %ActivityLog{}
    |> ActivityLog.changeset(Map.new(attrs))
    |> Repo.insert()
  end

  @spec list_user_activity_logs(integer(), keyword()) :: [ActivityLog.t()]
  def list_user_activity_logs(user_id, opts \\ []) when is_integer(user_id) do
    limit = Keyword.get(opts, :limit, 50)

    ActivityLog
    |> where([l], l.target_user_id == ^user_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload([:admin])
    |> Repo.all()
  end
end
