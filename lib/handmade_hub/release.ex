defmodule HandmadeHub.Release do
  @moduledoc """
  Release tasks for running database migrations in production.
  """

  @app :handmade_hub

  @doc """
  Run all pending migrations for all configured Ecto repos.
  """
  def migrate do
    Application.load(@app)

    repos()
    |> Enum.each(fn repo ->
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end)
  end

  @doc """
  Roll back to a specific version for the given `repo`.
  """
  def rollback(repo, version) do
    Application.load(@app)

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, :down, to: version)
      end)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end
end
