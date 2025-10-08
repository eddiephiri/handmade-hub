# Test script for Admin Approval System
# Run this in IEx console: mix run test_admin_approval_system.exs

alias HandmadeHub.{Admins, Repo}
alias HandmadeHub.Admins.Admin

IO.puts("\n========================================")
IO.puts("Admin Approval System Test Script")
IO.puts("========================================\n")

# Step 1: Create a super admin (approved by default for testing)
IO.puts("Step 1: Creating super_admin...")
{:ok, super_admin} = Admins.register_admin(%{
  email: "super@example.com",
  username: "superadmin",
  password: "SecurePass123",
  role: "super_admin"
})

# Manually approve the super admin
super_admin
|> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
|> Repo.update!()

IO.puts("✓ Super admin created and approved")
IO.puts("  Email: super@example.com")
IO.puts("  Password: SecurePass123")
IO.puts("  Status: #{if super_admin.confirmed_at, do: "Approved", else: "Pending"}")

# Step 2: Create a moderator (will be pending)
IO.puts("\nStep 2: Creating moderator (pending)...")
{:ok, moderator} = Admins.register_admin(%{
  email: "moderator@example.com",
  username: "moderator1",
  password: "ModeratorPass123",
  role: "moderator"
})

IO.puts("✓ Moderator created")
IO.puts("  Email: moderator@example.com")
IO.puts("  Password: ModeratorPass123")
IO.puts("  Status: #{if moderator.confirmed_at, do: "Approved", else: "Pending"}")

# Step 3: List pending admins
IO.puts("\nStep 3: Listing pending admins...")
pending = Admins.pending_admins()
IO.puts("✓ Found #{length(pending)} pending admin(s)")
Enum.each(pending, fn admin ->
  IO.puts("  - #{admin.username} (#{admin.email})")
end)

# Step 4: List approved admins
IO.puts("\nStep 4: Listing approved admins...")
approved = Admins.approved_admins()
IO.puts("✓ Found #{length(approved)} approved admin(s)")
Enum.each(approved, fn admin ->
  IO.puts("  - #{admin.username} (#{admin.email})")
end)

# Step 5: Test approval
IO.puts("\nStep 5: Approving moderator...")
{:ok, approved_moderator} = Admins.approve_admin(moderator)
IO.puts("✓ Moderator approved successfully")
IO.puts("  Status: #{if approved_moderator.confirmed_at, do: "Approved", else: "Pending"}")

# Step 6: Create another admin for rejection test
IO.puts("\nStep 6: Creating support user for rejection test...")
{:ok, support} = Admins.register_admin(%{
  email: "support@example.com",
  username: "support1",
  password: "SupportPass123",
  role: "support"
})
IO.puts("✓ Support user created (pending)")

# Step 7: Test rejection
IO.puts("\nStep 7: Rejecting support user...")
{:ok, _} = Admins.reject_admin(support)
IO.puts("✓ Support user rejected and removed")

# Step 8: Final count
IO.puts("\nStep 8: Final admin count...")
all_admins = Admins.list_admins()
IO.puts("✓ Total admins: #{length(all_admins)}")
IO.puts("  - Approved: #{length(Admins.approved_admins())}")
IO.puts("  - Pending: #{length(Admins.pending_admins())}")

IO.puts("\n========================================")
IO.puts("Test completed successfully!")
IO.puts("========================================")
IO.puts("\nNext steps:")
IO.puts("1. Start your Phoenix server: mix phx.server")
IO.puts("2. Log in at: http://localhost:4000/admin/log_in")
IO.puts("3. Use credentials:")
IO.puts("   Email: super@example.com")
IO.puts("   Password: SecurePass123")
IO.puts("4. Navigate to: /admin/admins")
IO.puts("5. Test creating, approving, and rejecting admins")
IO.puts("\n")
