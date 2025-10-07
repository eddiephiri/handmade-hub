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

  @doc """
  Run database seeds.
  """
  def seed do
    # Load the application
    Application.load(@app)

    # Start necessary applications
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto)

    # Get the repo and start it within Ecto.Migrator context
    repos()
    |> Enum.each(fn repo ->
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seed_script = Path.join([priv_dir(), "repo", "seeds.exs"])

          if File.exists?(seed_script) do
            IO.puts("Running seed script: #{seed_script}")
            Code.eval_file(seed_script)
            IO.puts("✅ Seeds completed successfully!")
          else
            IO.puts("⚠️  Seed script not found at #{seed_script}")
          end

          {:ok, nil, nil}
        end)
    end)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp priv_dir do
    Application.app_dir(@app, "priv")
  end
end
