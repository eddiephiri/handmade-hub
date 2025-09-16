# Test email delivery to eddiephiri44@gmail.com
# Run this in the Phoenix console: iex -S mix

IO.puts("🧪 Testing email delivery to eddiephiri44@gmail.com...")

# Create a simple user struct
user = %{email: "eddiephiri44@gmail.com"}

# Test UserNotifier
IO.puts("\n📧 Testing UserNotifier...")
{:ok, email} = HandmadeHub.Accounts.UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

IO.puts("✅ Email created successfully!")
IO.puts("📧 To: #{inspect(email.to)}")
IO.puts("📧 Subject: #{email.subject}")
IO.puts("📧 From: #{inspect(email.from)}")
IO.puts("📧 Body preview: #{String.slice(email.text_body, 0, 150)}...")

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

# Test email processing
IO.puts("\n⚡ Testing email processing...")
result = HandmadeHub.Notifications.dispatch_pending_emails()
IO.puts("📊 Processing result: #{inspect(result)}")

IO.puts("\n🎉 Email delivery test completed!")
IO.puts("📧 All emails were processed for eddiephiri44@gmail.com")
