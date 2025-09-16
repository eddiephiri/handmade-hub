# Alternative Gmail SMTP configuration
# This uses different TLS settings that might work better
# Run with: mix run --config config/dev_gmail_alternative.exs test_gmail_email.exs

import Config

# Configure the mailer to use Gmail SMTP with alternative settings
config :handmade_hub, HandmadeHub.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: System.get_env("GMAIL_USERNAME", "eddiephiri44@gmail.com"),
  password: System.get_env("GMAIL_APP_PASSWORD", "YOUR_16_CHAR_APP_PASSWORD"),
  tls: :if_available,
  ssl: false,
  auth: :always,
  retries: 2,
  no_mx_lookups: false,
  helo: "localhost",
  tls_options: [
    verify: :verify_none
  ]

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
