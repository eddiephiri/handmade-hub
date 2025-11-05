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
alias HandmadeHub.Admins
alias HandmadeHub.Admins.Admin
alias HandmadeHub.Delivery
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

  def create_admin(attrs) do
    IO.puts("Creating admin with email: #{attrs[:email]}")
    admin = %Admin{}
    case Admin.registration_changeset(admin, attrs) |> Repo.insert() do
      {:ok, admin} ->
        admin
        |> change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
        |> Repo.update!()
        IO.puts("Successfully created admin: #{attrs[:email]}")
      {:error, changeset} ->
        IO.inspect(changeset, label: "Error creating admin: #{attrs[:email]}")
    end
  end

  def create_rider(attrs) do
    IO.puts("Creating rider: #{attrs[:name]}")
    case Delivery.create_rider(attrs) do
      {:ok, rider} ->
        IO.puts("Successfully created rider: #{attrs[:name]}")
      {:error, changeset} ->
        IO.inspect(changeset, label: "Error creating rider: #{attrs[:name]}")
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

# Create an admin user for tests
Seed.create_admin(%{
  email: "admin@example.com",
  username: "admin",
  password: "password1234",
  role: "super_admin",
  permissions: %{"all" => true}
})

# Create delivery riders
Seed.create_rider(%{
  name: "John Banda",
  phone_number: "0977123456",
  status: "active",
  vehicle_type: "motorbike"
})

Seed.create_rider(%{
  name: "Mary Mwamba",
  phone_number: "0977456789",
  status: "active",
  vehicle_type: "motorbike"
})

Seed.create_rider(%{
  name: "Peter Chanda",
  phone_number: "0977567890",
  status: "active",
  vehicle_type: "motorbike"
})

IO.puts("Database seeding finished.")
