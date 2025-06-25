defmodule HandmadeHub.Repo do
  use Ecto.Repo,
    otp_app: :handmade_hub,
    adapter: Ecto.Adapters.Postgres
end
