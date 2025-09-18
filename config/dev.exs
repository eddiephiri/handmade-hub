# Development configuration with Gmail SMTP email delivery
# This file uses environment variables for security

import Config

# Configure your database
config :handmade_hub, HandmadeHub.Repo,
  username: "postgres",
  password: "5c0rp1027",
  hostname: "localhost",
  database: "handmade_hub_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :handmade_hub, HandmadeHubWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "UTk8jA+NLz42FA0eDu1df9SDyxKG4Q5wuqyA+dLnCbpxwb597a/YDWYQiApTR/4C",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:handmade_hub, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:handmade_hub, ~w(--watch)]}
  ]

# Enable dev routes for dashboard and mailbox
config :handmade_hub, dev_routes: true

# Configure the mailer to use Gmail SMTP for real email delivery
# This sends actual emails that you can read in your Gmail inbox
# Perfect for demonstrations and project defense presentations
config :handmade_hub, HandmadeHub.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: System.get_env("GMAIL_USERNAME", "eddiephiri44@gmail.com"),
  password: System.get_env("GMAIL_APP_PASSWORD", "jncnbfnwtjuobsis"),
  tls: :always,
  ssl: false,
  auth: :always,
  retries: 2,
  no_mx_lookups: false,
  helo: "localhost",
  tls_options: [
    verify: :verify_none,
    server_name_indication: :disable,
    customize_hostname_check: [
      match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ]

# Configure Swoosh API Client
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Other development settings...
config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true
