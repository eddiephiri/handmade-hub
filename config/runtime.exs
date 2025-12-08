import Config

delivery_minutes_env = System.get_env("DELIVERY_SIMULATION_MINUTES")

if delivery_minutes_env do
  case Integer.parse(delivery_minutes_env) do
    {minutes, ""} when minutes >= 0 ->
      config :handmade_hub, :delivery_simulator, delivery_time_minutes: minutes

    _ ->
      IO.warn(
        "DELIVERY_SIMULATION_MINUTES must be a non-negative integer, received #{inspect(delivery_minutes_env)}"
      )
  end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/handmade_hub start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :handmade_hub, HandmadeHubWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  pool_size_env = System.get_env("POOL_SIZE") || "10"
  pool_size = case Integer.parse(pool_size_env) do
    {size, ""} -> size
    _ -> raise """
      Invalid POOL_SIZE value: #{inspect(pool_size_env)}.
      POOL_SIZE must be a valid integer.
      """
  end

  config :handmade_hub, HandmadeHub.Repo,
    # ssl: true,
    url: database_url,
    pool_size: pool_size,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port_env = System.get_env("PHX_PORT") || System.get_env("PORT") || "9706"
  port = case Integer.parse(port_env) do
    {port_num, ""} -> port_num
    _ -> raise """
      Invalid port value: #{inspect(port_env)}.
      PHX_PORT or PORT must be a valid integer.
      """
  end

  config :handmade_hub, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :handmade_hub, HandmadeHubWeb.Endpoint,
    url: [host: host, port: port, scheme: "http"],
    http: [
      # Bind on all IPv4 interfaces (0.0.0.0)
      # For IPv6, use {0, 0, 0, 0, 0, 0, 0, 0}
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :handmade_hub, HandmadeHubWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :handmade_hub, HandmadeHubWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # Configure email delivery for production using environment variables
  # You can use either Gmail SMTP or SendGrid SMTP

  # Option 1: Gmail SMTP (if you have Gmail credentials)
  if System.get_env("GMAIL_USERNAME") && System.get_env("GMAIL_APP_PASSWORD") do
    config :handmade_hub, HandmadeHub.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: "smtp.gmail.com",
      port: 587,
      username: System.get_env("GMAIL_USERNAME"),
      password: System.get_env("GMAIL_APP_PASSWORD"),
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
  end

  # Option 2: SendGrid SMTP (if you have SendGrid credentials)
  if System.get_env("SENDGRID_API_KEY") do
    config :handmade_hub, HandmadeHub.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: "smtp.sendgrid.net",
      port: 587,
      username: "apikey",
      password: System.get_env("SENDGRID_API_KEY"),
      tls: :always,
      ssl: false,
      auth: :always,
      retries: 2,
      no_mx_lookups: false
  end

  # Fallback: Use Local adapter if no SMTP credentials are provided
  # This prevents the application from crashing if email credentials are not configured
  unless System.get_env("GMAIL_USERNAME") || System.get_env("SENDGRID_API_KEY") do
    config :handmade_hub, HandmadeHub.Mailer,
      adapter: Swoosh.Adapters.Local
  end

  # Configure Swoosh API Client
  config :swoosh, :api_client, Swoosh.ApiClient.Finch

  # Configure pawaPay payment gateway
  config :handmade_hub,
    pawapay_api_token: System.get_env("PAWAPAY_API_TOKEN"),
    pawapay_base_url: System.get_env("PAWAPAY_BASE_URL") || "https://api.sandbox.pawapay.io",
    pawapay_callback_url: System.get_env("PAWAPAY_CALLBACK_URL")
end
