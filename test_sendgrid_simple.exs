#!/usr/bin/env elixir

# Test SendGrid email delivery
# Run with: mix run test_sendgrid_simple.exs

IO.puts("🧪 Testing SendGrid email delivery...")

# Check if environment variables are set
sendgrid_api_key = System.get_env("SENDGRID_API_KEY")

if sendgrid_api_key && sendgrid_api_key != "YOUR_SENDGRID_API_KEY" do
  IO.puts("✅ SendGrid API key found in environment variables")
  IO.puts("🔑 API Key: #{String.slice(sendgrid_api_key, 0, 8)}****")
else
  IO.puts("⚠️  SendGrid API key not found in environment variables")
  IO.puts("📝 Please set SENDGRID_API_KEY environment variable")
  IO.puts("📝 Example:")
  IO.puts("   set SENDGRID_API_KEY=your-sendgrid-api-key")
  IO.puts("📝 Get your API key from: https://app.sendgrid.com/settings/api_keys")
  System.halt(1)
end

# Test email creation
IO.puts("\n📧 Creating test email...")
user = %{email: "eddiephiri44@gmail.com"}

{:ok, email} = HandmadeHub.Accounts.UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

IO.puts("✅ Email created successfully!")
IO.puts("📧 To: #{inspect(email.to)}")
IO.puts("📧 Subject: #{email.subject}")
IO.puts("📧 From: #{inspect(email.from)}")

# Test email delivery
IO.puts("\n🚀 Attempting to send email via SendGrid...")
case HandmadeHub.Mailer.deliver(email) do
  {:ok, metadata} ->
    IO.puts("✅ Email sent successfully!")
    IO.puts("📧 Check your inbox at eddiephiri44@gmail.com")
    IO.puts("📧 SendGrid response: #{inspect(metadata)}")
  {:error, reason} ->
    IO.puts("❌ Email delivery failed:")
    IO.puts("📧 Error: #{inspect(reason)}")
    IO.puts("📧 This might be due to:")
    IO.puts("   - Invalid SendGrid API key")
    IO.puts("   - SendGrid account not verified")
    IO.puts("   - Network/firewall blocking SMTP connection")
    IO.puts("📧 Please check your SendGrid settings and try again")
  other ->
    IO.puts("❌ Unexpected response:")
    IO.puts("📧 Response: #{inspect(other)}")
end

IO.puts("\n🎉 SendGrid email test completed!")
