# Quick test to verify email creation
# Run with: mix run test_email_verification.exs

IO.puts("🧪 Testing email creation for eddiephiri44@gmail.com...")

# Create a simple user struct
user = %{email: "eddiephiri44@gmail.com"}

# Test UserNotifier
IO.puts("\n📧 Creating confirmation email...")
{:ok, email} = HandmadeHub.Accounts.UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

IO.puts("✅ Email created successfully!")
IO.puts("📧 To: #{inspect(email.to)}")
IO.puts("📧 Subject: #{email.subject}")
IO.puts("📧 From: #{inspect(email.from)}")
IO.puts("📧 Body length: #{String.length(email.text_body)} characters")

# Test email queue
IO.puts("\n📬 Testing email queue...")
{:ok, queued_email} = HandmadeHub.Notifications.enqueue_email(%{
  to: "eddiephiri44@gmail.com",
  subject: "Test Email for Eddie",
  text_body: "Hello Eddie! This is a test email from HandmadeHub.",
  type: "test"
})

IO.puts("✅ Email enqueued successfully!")
IO.puts("📧 Queue ID: #{queued_email.id}")
IO.puts("📧 Status: #{queued_email.status}")

# Process the email
IO.puts("\n⚡ Processing email...")
result = HandmadeHub.Notifications.dispatch_pending_emails()
IO.puts("📊 Processing result: #{inspect(result)}")

IO.puts("\n🎉 Email test completed!")
IO.puts("📧 Check http://localhost:4000/dev/mailbox to see the emails")
IO.puts("📧 The emails are stored locally and not sent to real addresses in development mode")
