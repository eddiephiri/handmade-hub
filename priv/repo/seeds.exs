# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     HandmadeHub.Repo.insert!(%HandmadeHub.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias HandmadeHub.Repo
alias HandmadeHub.Accounts
alias HandmadeHub.Accounts.User
import Ecto.Changeset

# Function to create a user, ensuring they are confirmed and have a profile
defmodule Seed do
  def create_user(attrs) do
    IO.puts("Creating user with email: #{attrs[:email]}")

    user_attrs = Map.take(attrs, [:email, :password, :role])
    profile_attrs = Map.take(attrs, [:name, :bio])

    case Accounts.register_user(user_attrs) do
      {:ok, user} ->
        user
        |> cast(profile_attrs, [:name, :bio])
        |> validate_length(:bio, max: 500)
        |> put_change(:confirmed_at, DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()

        IO.puts("Successfully created user: #{attrs[:email]}")

      {:error, changeset} ->
        IO.inspect(changeset, label: "Error creating user: #{attrs[:email]}")
    end
  end
end

IO.puts("Seeding database...")

# Create an artisan user
Seed.create_user(%{
  email: "artisan@example.com",
  password: "password1234",
  role: "artisan",
  name: "Artisan Person",
  bio: "I make things with my hands."
})

# Create a buyer user
Seed.create_user(%{
  email: "buyer@example.com",
  password: "password1234",
  role: "buyer",
  name: "Buyer Person",
  bio: "I buy things."
})

IO.puts("Database seeding finished.")
