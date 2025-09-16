# Test Gmail email delivery with simple configuration
# Run with: mix run --config config/dev_gmail_simple.exs test_gmail_simple.exs

IO.puts("🧪 Testing Gmail email delivery with simple configuration...")

# Check if environment variables are set
gmail_username = System.get_env("GMAIL_USERNAME")
gmail_password = System.get_env("GMAIL_APP_PASSWORD")

if gmail_username && gmail_password do
  IO.puts("✅ Gmail credentials found in environment variables")
  IO.puts("📧 Username: #{gmail_username}")
  IO.puts("🔑 Password: #{String.slice(gmail_password, 0, 4)}****")
else
  IO.puts("⚠️  Gmail credentials not found in environment variables")
  IO.puts("📝 Please set GMAIL_USERNAME and GMAIL_APP_PASSWORD")
  IO.puts("📝 Example:")
  IO.puts("   set GMAIL_USERNAME=eddiephiri44@gmail.com")
  IO.puts("   set GMAIL_APP_PASSWORD=your-16-character-app-password")
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
IO.puts("\n🚀 Attempting to send email...")
case HandmadeHub.Mailer.deliver(email) do
  {:ok, _metadata} ->
    IO.puts("✅ Email sent successfully!")
    IO.puts("📧 Check your inbox at eddiephiri44@gmail.com")
  {:error, reason} ->
    IO.puts("❌ Email delivery failed:")
    IO.puts("📧 Error: #{inspect(reason)}")
    IO.puts("📧 This might be due to:")
    IO.puts("   - Incorrect Gmail app password")
    IO.puts("   - 2FA not enabled on Gmail account")
    IO.puts("   - App password not generated correctly")
    IO.puts("   - Network/firewall blocking SMTP connection")
    IO.puts("📧 Please check your Gmail settings and try again")
  other ->
    IO.puts("❌ Unexpected response:")
    IO.puts("📧 Response: #{inspect(other)}")
end

IO.puts("\n🎉 Gmail email test completed!")
