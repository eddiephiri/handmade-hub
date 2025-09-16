# Local email configuration for development
# This stores emails locally and you can view them in the browser
# Run with: mix run --config config/dev_local_email.exs test_local_email.exs

import Config

# Configure the mailer to use local storage (no actual sending)
config :handmade_hub, HandmadeHub.Mailer,
  adapter: Swoosh.Adapters.Local

# Configure Swoosh API Client
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Other development settings...
config :handmade_hub, HandmadeHubWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "your-secret-key-here",
  live_view: [signing_salt: "your-signing-salt-here"]

# Configure the database
config :handmade_hub, HandmadeHub.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "handmade_hub_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

