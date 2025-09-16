# Working SendGrid configuration for email delivery
# This is more reliable than Gmail SMTP on Windows
# Run with: mix run --config config/dev_sendgrid_working.exs test_sendgrid_email.exs

import Config

# Configure the mailer to use SendGrid SMTP
config :handmade_hub, HandmadeHub.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.sendgrid.net",
  port: 587,
  username: "apikey",  # This is always "apikey" for SendGrid
  password: System.get_env("SENDGRID_API_KEY", "YOUR_SENDGRID_API_KEY"),
  tls: :always,
  ssl: false,
  auth: :always,
  retries: 2,
  no_mx_lookups: false

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

