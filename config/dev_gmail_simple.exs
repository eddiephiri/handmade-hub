# Simple Gmail SMTP configuration
# This is a minimal configuration that should work with Gmail
# Run with: mix run --config config/dev_gmail_simple.exs test_gmail_email.exs

import Config

# Configure the mailer to use Gmail SMTP with minimal settings
config :handmade_hub, HandmadeHub.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: System.get_env("GMAIL_USERNAME", "eddiephiri44@gmail.com"),
  password: System.get_env("GMAIL_APP_PASSWORD", "YOUR_16_CHAR_APP_PASSWORD"),
  tls: :always,
  auth: :always

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

# Configure Swoosh
config :swoosh, :api_client, Swoosh.ApiClient.Finch
