defmodule SimpleEmailTest do
  use ExUnit.Case, async: false

  alias HandmadeHub.Accounts.UserNotifier
  alias HandmadeHub.Notifications

  test "sends email to eddiephiri44@gmail.com" do
    # Create a simple user struct for testing
    user = %{email: "eddiephiri44@gmail.com"}

    # Test confirmation email
    {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

    # Verify the email was created correctly
    assert email.to == [{"", "eddiephiri44@gmail.com"}]
    assert email.subject == "Confirmation instructions"
    assert email.from == {"HandmadeHub", "contact@example.com"}
    assert String.contains?(email.text_body, "eddiephiri44@gmail.com")
    assert String.contains?(email.text_body, "confirm your account")

    IO.puts("✅ Email successfully created for eddiephiri44@gmail.com")
    IO.puts("📧 Subject: #{email.subject}")
    IO.puts("📧 To: #{inspect(email.to)}")
    IO.puts("📧 From: #{inspect(email.from)}")
    IO.puts("📧 Body preview: #{String.slice(email.text_body, 0, 100)}...")
  end

  test "enqueues email for eddiephiri44@gmail.com" do
    {:ok, queued_email} = Notifications.enqueue_email(%{
      to: "eddiephiri44@gmail.com",
      subject: "Test Email for Eddie",
      text_body: "Hello Eddie! This is a test email from HandmadeHub.",
      type: "test"
    })

    assert queued_email.to == "eddiephiri44@gmail.com"
    assert queued_email.subject == "Test Email for Eddie"
    assert queued_email.status == "pending"

    IO.puts("✅ Email successfully enqueued for eddiephiri44@gmail.com")
    IO.puts("📧 Queue ID: #{queued_email.id}")
    IO.puts("📧 Status: #{queued_email.status}")
  end
end
