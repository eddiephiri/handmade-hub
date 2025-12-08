defmodule HandmadeHub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HandmadeHubWeb.Telemetry,
      HandmadeHub.Repo,
      {DNSCluster, query: Application.get_env(:handmade_hub, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HandmadeHub.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: HandmadeHub.Finch},
      # Scheduler for background jobs
      HandmadeHub.Scheduler,
      # Start a worker by calling: HandmadeHub.Worker.start_link(arg)
      # {HandmadeHub.Worker, arg},
      # Start to serve requests, typically the last entry
      HandmadeHubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HandmadeHub.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:shutdown, reason}} ->
        require Logger
        Logger.error("Application failed to start: #{inspect(reason)}")
        {:error, reason}
      {:error, reason} ->
        require Logger
        Logger.error("Application failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HandmadeHubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
