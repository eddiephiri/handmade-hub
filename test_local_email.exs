# Test local email storage
# Run with: mix run --config config/dev_local_email.exs test_local_email.exs

IO.puts("🧪 Testing local email storage...")

# Test email creation
IO.puts("\n📧 Creating test email...")
user = %{email: "eddiephiri44@gmail.com"}

{:ok, email} = HandmadeHub.Accounts.UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

IO.puts("✅ Email created successfully!")
IO.puts("📧 To: #{inspect(email.to)}")
IO.puts("📧 Subject: #{email.subject}")
IO.puts("📧 From: #{inspect(email.from)}")

# Test email delivery (local storage)
IO.puts("\n🚀 Storing email locally...")
case HandmadeHub.Mailer.deliver(email) do
  {:ok, _metadata} ->
    IO.puts("✅ Email stored successfully!")
    IO.puts("📧 View emails at: http://localhost:4000/dev/mailbox")
    IO.puts("📧 Start your Phoenix server with: mix phx.server")
  {:error, reason} ->
    IO.puts("❌ Email storage failed:")
    IO.puts("📧 Error: #{inspect(reason)}")
  other ->
    IO.puts("❌ Unexpected response:")
    IO.puts("📧 Response: #{inspect(other)}")
end

IO.puts("\n🎉 Local email test completed!")

