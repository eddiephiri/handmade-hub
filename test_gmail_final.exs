#!/usr/bin/env elixir

# Final Gmail test for project defense
# Run with: mix run test_gmail_final.exs

IO.puts("🎓 Testing Gmail email delivery for project defense...")
IO.puts("📧 This will send a real email to eddiephiri44@gmail.com")
IO.puts("")

# Test email creation
IO.puts("📧 Creating test email...")
user = %{email: "eddiephiri44@gmail.com"}

{:ok, email} = HandmadeHub.Accounts.UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

IO.puts("✅ Email created successfully!")
IO.puts("📧 To: #{inspect(email.to)}")
IO.puts("📧 Subject: #{email.subject}")
IO.puts("📧 From: #{inspect(email.from)}")
IO.puts("")

# Test email delivery
IO.puts("🚀 Sending email via Gmail SMTP...")
IO.puts("⏳ This may take a few seconds...")

case HandmadeHub.Mailer.deliver(email) do
  {:ok, metadata} ->
    IO.puts("✅ Email sent successfully!")
    IO.puts("📧 Check your Gmail inbox at eddiephiri44@gmail.com")
    IO.puts("📧 Metadata: #{inspect(metadata)}")
    IO.puts("")
    IO.puts("🎉 Perfect for your project defense presentation!")
  {:error, reason} ->
    IO.puts("❌ Email delivery failed:")
    IO.puts("📧 Error: #{inspect(reason)}")
    IO.puts("")
    IO.puts("🔧 Troubleshooting:")
    IO.puts("   - Check Gmail app password")
    IO.puts("   - Verify 2FA is enabled")
    IO.puts("   - Check network connection")
  other ->
    IO.puts("❌ Unexpected response:")
    IO.puts("📧 Response: #{inspect(other)}")
end

IO.puts("")
IO.puts("🎓 Gmail email test completed!")
IO.puts("📧 Ready for your final year presentation!")
