defmodule HandmadeHub.EmailDeliveryTest do
  use HandmadeHub.DataCase, async: false

  alias HandmadeHub.Accounts
  alias HandmadeHub.Accounts.UserNotifier
  alias HandmadeHub.Notifications
  alias HandmadeHub.Notifications.EmailQueue
  alias HandmadeHub.Repo
  import HandmadeHub.AccountsFixtures

  describe "email delivery to valid address" do
    test "sends confirmation email to eddiephiri44@gmail.com" do
      # Create a test user with the specific email address
      user = user_fixture(%{email: "eddiephiri44@gmail.com"})

      # Send confirmation email
      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test123")

      # Verify email was created with correct recipient
      assert email.to == [{"", "eddiephiri44@gmail.com"}]
      assert email.subject == "Confirmation instructions"
      assert email.from == {"HandmadeHub", "contact@example.com"}

      # Verify email content
      assert String.contains?(email.text_body, "Hi eddiephiri44@gmail.com")
      assert String.contains?(email.text_body, "confirm your account")
      assert String.contains?(email.text_body, "https://handmadehub.com/confirm?token=test123")
    end

    test "sends password reset email to eddiephiri44@gmail.com" do
      user = user_fixture(%{email: "eddiephiri44@gmail.com"})

      {:ok, email} = UserNotifier.deliver_reset_password_instructions(user, "https://handmadehub.com/reset?token=reset456")

      assert email.to == [{"", "eddiephiri44@gmail.com"}]
      assert email.subject == "Reset password instructions"
      assert String.contains?(email.text_body, "reset your password")
    end

    test "sends email update instructions to eddiephiri44@gmail.com" do
      user = user_fixture(%{email: "eddiephiri44@gmail.com"})

      {:ok, email} = UserNotifier.deliver_update_email_instructions(user, "https://handmadehub.com/update?token=update789")

      assert email.to == [{"", "eddiephiri44@gmail.com"}]
      assert email.subject == "Update email instructions"
      assert String.contains?(email.text_body, "change your email")
    end

    test "enqueues email for eddiephiri44@gmail.com" do
      {:ok, queued_email} = Notifications.enqueue_email(%{
        to: "eddiephiri44@gmail.com",
        subject: "Test Email to Eddie",
        text_body: "Hello Eddie! This is a test email from HandmadeHub.",
        type: "test",
        scheduled_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert queued_email.to == "eddiephiri44@gmail.com"
      assert queued_email.subject == "Test Email to Eddie"
      assert queued_email.text_body == "Hello Eddie! This is a test email from HandmadeHub."
      assert queued_email.type == "test"
      assert queued_email.status == "pending"
    end

    test "processes and sends queued email to eddiephiri44@gmail.com" do
      # Enqueue an email for immediate delivery
      past_time = DateTime.add(DateTime.utc_now(), -60) |> DateTime.truncate(:second)

      {:ok, queued_email} = Notifications.enqueue_email(%{
        to: "eddiephiri44@gmail.com",
        subject: "Immediate Test Email",
        text_body: "This email should be sent immediately to Eddie.",
        type: "immediate_test",
        scheduled_at: past_time
      })

      # Process the email queue
      result = Notifications.dispatch_pending_emails()
      assert %{sent: 1, retried: 0, failed: 0} = result

      # Verify the email was marked as sent
      reloaded = Repo.get!(EmailQueue, queued_email.id)
      assert reloaded.status == "sent"
      assert reloaded.sent_at != nil
      assert reloaded.attempts == 1
      assert reloaded.last_error == nil
    end

    test "handles user registration flow with eddiephiri44@gmail.com" do
      # Test the complete registration flow
      user_attrs = %{
        email: "eddiephiri44@gmail.com",
        password: "validpassword123",
        role: "buyer"
      }

      # Register user
      {:ok, user} = Accounts.register_user(user_attrs)
      assert user.email == "eddiephiri44@gmail.com"
      refute user.confirmed_at

      # Send confirmation instructions
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "https://handmadehub.com/confirm?token=test" end)

      # Verify user token was created
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      assert hd(tokens).context == "confirm"
    end

    test "verifies email format validation for eddiephiri44@gmail.com" do
      # Test that the email address passes validation
      user_attrs = %{
        email: "eddiephiri44@gmail.com",
        password: "validpassword123",
        role: "buyer"
      }

      changeset = HandmadeHub.Accounts.User.registration_changeset(%HandmadeHub.Accounts.User{}, user_attrs)
      assert changeset.valid?
      assert changeset.changes.email == "eddiephiri44@gmail.com"
    end

    test "sends multiple emails to eddiephiri44@gmail.com" do
      user = user_fixture(%{email: "eddiephiri44@gmail.com"})

      # Send multiple types of emails
      {:ok, confirmation_email} = UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test1")
      {:ok, reset_email} = UserNotifier.deliver_reset_password_instructions(user, "https://handmadehub.com/reset?token=test2")
      {:ok, update_email} = UserNotifier.deliver_update_email_instructions(user, "https://handmadehub.com/update?token=test3")

      # All emails should be sent to the same address
      assert confirmation_email.to == [{"", "eddiephiri44@gmail.com"}]
      assert reset_email.to == [{"", "eddiephiri44@gmail.com"}]
      assert update_email.to == [{"", "eddiephiri44@gmail.com"}]

      # All should have different subjects
      assert confirmation_email.subject == "Confirmation instructions"
      assert reset_email.subject == "Reset password instructions"
      assert update_email.subject == "Update email instructions"
    end

    test "handles email delivery with special characters in content" do
      user = user_fixture(%{email: "eddiephiri44@gmail.com"})

      # Test with special characters in the URL
      special_url = "https://handmadehub.com/confirm?token=test&special=chars&email=eddiephiri44@gmail.com"

      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, special_url)

      assert email.to == [{"", "eddiephiri44@gmail.com"}]
      assert String.contains?(email.text_body, special_url)
      assert String.contains?(email.text_body, "eddiephiri44@gmail.com")
    end
  end

  describe "email delivery edge cases" do
    test "handles case sensitivity in email address" do
      # Test with different case variations
      user = user_fixture(%{email: "EDDIEPHIRI44@GMAIL.COM"})

      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test")

      # Should preserve the original case in the email
      assert email.to == [{"", "EDDIEPHIRI44@GMAIL.COM"}]
    end

    test "handles email with plus sign (Gmail alias)" do
      # Gmail supports aliases with plus signs
      user = user_fixture(%{email: "eddiephiri44+test@gmail.com"})

      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, "https://handmadehub.com/confirm?token=test")

      assert email.to == [{"", "eddiephiri44+test@gmail.com"}]
      assert String.contains?(email.text_body, "eddiephiri44+test@gmail.com")
    end

    test "verifies email queue processing with specific recipient" do
      # Create multiple emails for different recipients
      past_time = DateTime.add(DateTime.utc_now(), -60) |> DateTime.truncate(:second)

      {:ok, _email1} = Notifications.enqueue_email(%{
        to: "eddiephiri44@gmail.com",
        subject: "Email for Eddie",
        text_body: "This is for Eddie",
        scheduled_at: past_time
      })

      {:ok, _email2} = Notifications.enqueue_email(%{
        to: "other@example.com",
        subject: "Email for Other",
        text_body: "This is for someone else",
        scheduled_at: past_time
      })

      # Process all emails
      result = Notifications.dispatch_pending_emails()
      assert %{sent: 2, retried: 0, failed: 0} = result

      # Verify both emails were sent
      emails = Repo.all(EmailQueue)
      eddie_email = Enum.find(emails, &(&1.to == "eddiephiri44@gmail.com"))
      other_email = Enum.find(emails, &(&1.to == "other@example.com"))

      assert eddie_email.status == "sent"
      assert other_email.status == "sent"
    end
  end
end
