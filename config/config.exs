# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :handmade_hub,
  ecto_repos: [HandmadeHub.Repo],
  generators: [timestamp_type: :utc_datetime],
  # Session validity (in minutes) for server-side tokens. Default 60 minutes.
  # Override per environment in dev.exs/prod.exs as needed.
  session_validity_minutes: 60,
  # Remember-me cookie max_age (in seconds). Default 60 days.
  remember_me_max_age: 60 * 60 * 24 * 60

# Configures the endpoint
config :handmade_hub, HandmadeHubWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HandmadeHubWeb.ErrorHTML, json: HandmadeHubWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HandmadeHub.PubSub,
  live_view: [signing_salt: "cIHCL21j"]

# Configures the mailer
#
# Email adapter is configured per environment:
# - Development: Uses Local adapter (see config/dev.exs)
# - Production: Uses SMTP adapter (see config/runtime.exs)
#
# The Local adapter stores emails locally and can be viewed at "/dev/mailbox".
# For production, SMTP adapters are configured in runtime.exs using environment variables.

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  handmade_hub: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  handmade_hub: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Quantum scheduler config
config :handmade_hub, HandmadeHub.Scheduler,
  timezone: :utc,
  jobs: [
    # Every minute, attempt to dispatch pending emails
    {"* * * * *", {HandmadeHub.Notifications, :dispatch_pending_emails, []}},
    # Every Monday at 9:00 AM UTC for weekly payouts
    {"0 9 * * 1", {HandmadeHub.Payments.PayoutScheduler, :process_scheduled_payouts, []}}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
