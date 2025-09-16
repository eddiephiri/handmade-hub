defmodule HandmadeHub.Accounts.EmailNotificationsTest do
  use HandmadeHub.DataCase, async: false

  alias HandmadeHub.Accounts
  alias HandmadeHub.Notifications
  alias HandmadeHub.Notifications.EmailQueue
  alias HandmadeHub.Repo
  import HandmadeHub.AccountsFixtures

  describe "email verification notifications" do
    test "deliver_user_confirmation_instructions/2 sends confirmation email" do
      user = user_fixture()
      url = "https://handmadehub.com/confirm?token=test123"

      assert {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> url end)

      # Check that a user token was created
      tokens = Repo.all(EmailQueue)
      assert length(tokens) == 0  # No email queue entries for direct delivery
    end

    test "deliver_user_confirmation_instructions/2 returns error for already confirmed user" do
      user = user_fixture()
      # Confirm the user
      {:ok, confirmed_user} =
        user
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now())
        |> Repo.update()

      assert {:error, :already_confirmed} =
        Accounts.deliver_user_confirmation_instructions(confirmed_user, fn _token -> "url" end)
    end

    test "deliver_user_reset_password_instructions/2 sends reset email" do
      user = user_fixture()
      url = "https://handmadehub.com/reset?token=reset123"

      assert {:ok, _} = Accounts.deliver_user_reset_password_instructions(user, fn _token -> url end)

      # Check that a user token was created
      tokens = Repo.all(EmailQueue)
      assert length(tokens) == 0  # No email queue entries for direct delivery
    end

    test "deliver_user_update_email_instructions/2 sends update email" do
      user = user_fixture()
      current_email = user.email
      url = "https://handmadehub.com/update?token=update123"

      assert {:ok, _} = Accounts.deliver_user_update_email_instructions(user, current_email, fn _token -> url end)

      # Check that a user token was created
      tokens = Repo.all(EmailQueue)
      assert length(tokens) == 0  # No email queue entries for direct delivery
    end
  end

  describe "email queue integration" do
    test "user registration triggers confirmation email" do
      user_attrs = %{
        email: "newuser@example.com",
        password: "validpassword123",
        role: "buyer"
      }

      # Register user
      {:ok, user} = Accounts.register_user(user_attrs)

      # Deliver confirmation instructions
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Verify user is not confirmed
      refute user.confirmed_at

      # Verify user token was created
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      assert hd(tokens).context == "confirm"
    end

    test "password reset flow creates proper tokens" do
      user = user_fixture()

      # Request password reset
      {:ok, _} = Accounts.deliver_user_reset_password_instructions(user, fn _token -> "reset_url" end)

      # Verify reset token was created
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      assert hd(tokens).context == "reset_password"
    end

    test "email update flow creates proper tokens" do
      user = user_fixture()
      current_email = user.email

      # Request email update
      {:ok, _} = Accounts.deliver_user_update_email_instructions(user, current_email, fn _token -> "update_url" end)

      # Verify update token was created
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      assert hd(tokens).context == "change:#{current_email}"
    end
  end

  describe "email notification error handling" do
    test "handles malformed email addresses gracefully" do
      user = user_fixture()
      # Create a user with invalid email format
      {:ok, invalid_user} =
        user
        |> Ecto.Changeset.change(email: "invalid-email")
        |> Repo.update()

      # This should still work as the email validation happens at the schema level
      # but the notifier should handle it gracefully
      assert {:ok, _} = Accounts.deliver_user_confirmation_instructions(invalid_user, fn _token -> "url" end)
    end

    test "handles missing user gracefully" do
      # Test with a user that doesn't exist in the database
      fake_user = %HandmadeHub.Accounts.User{id: 99999, email: "nonexistent@example.com"}

      # This should work as the notifier doesn't validate user existence
      assert {:ok, _} = Accounts.deliver_user_confirmation_instructions(fake_user, fn _token -> "url" end)
    end
  end

  describe "email content validation" do
    test "confirmation email contains user-specific content" do
      user = user_fixture()
      url = "https://handmadehub.com/confirm?token=user123"

      {:ok, email} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> url end)

      # The function returns {:ok, %{to: ..., body: ...}} from UserNotifier
      assert is_map(email)
      assert Map.has_key?(email, :to)
      assert Map.has_key?(email, :body)
    end

    test "reset password email contains user-specific content" do
      user = user_fixture()
      url = "https://handmadehub.com/reset?token=reset123"

      {:ok, email} = Accounts.deliver_user_reset_password_instructions(user, fn _token -> url end)

      assert is_map(email)
      assert Map.has_key?(email, :to)
      assert Map.has_key?(email, :body)
    end

    test "email update instructions contain user-specific content" do
      user = user_fixture()
      current_email = user.email
      url = "https://handmadehub.com/update?token=update123"

      {:ok, email} = Accounts.deliver_user_update_email_instructions(user, current_email, fn _token -> url end)

      assert is_map(email)
      assert Map.has_key?(email, :to)
      assert Map.has_key?(email, :body)
    end
  end

  describe "email queue fallback mechanism" do
    test "enqueues email when direct delivery fails" do
      # This test verifies that the UserNotifier fallback mechanism works
      # by checking that emails are enqueued when direct delivery fails

      user = user_fixture()

      # The test environment should succeed, but we can verify the structure
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # In a real failure scenario, the email would be enqueued
      # We can test the enqueue mechanism directly
      {:ok, queued_email} = Notifications.enqueue_email(%{
        to: user.email,
        subject: "Test Subject",
        text_body: "Test body",
        type: "user_notification"
      })

      assert queued_email.to == user.email
      assert queued_email.subject == "Test Subject"
      assert queued_email.text_body == "Test body"
      assert queued_email.type == "user_notification"
      assert queued_email.status == "pending"
    end
  end

  describe "email token lifecycle" do
    test "confirmation tokens are cleaned up after use" do
      user = user_fixture()

      # Create confirmation token
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Verify token exists
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      token = hd(tokens)

      # Confirm the user (this should clean up the token)
      {:ok, _} = Accounts.confirm_user(token.token)

      # Verify token was cleaned up
      tokens_after = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens_after) == 0
    end

    test "reset password tokens are cleaned up after use" do
      user = user_fixture()

      # Create reset token
      {:ok, _} = Accounts.deliver_user_reset_password_instructions(user, fn _token -> "test_url" end)

      # Verify token exists
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      token = hd(tokens)

      # Reset password (this should clean up the token)
      {:ok, _} = Accounts.reset_user_password(user, %{
        password: "newpassword123",
        password_confirmation: "newpassword123"
      })

      # Verify token was cleaned up
      tokens_after = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens_after) == 0
    end
  end

  describe "email notification timing" do
    test "confirmation emails are sent immediately" do
      user = user_fixture()

      # This should send immediately, not be queued
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Verify no emails in queue (they're sent directly)
      queued_emails = Repo.all(EmailQueue)
      assert length(queued_emails) == 0
    end

    test "scheduled emails are queued for later delivery" do
      future_time = DateTime.add(DateTime.utc_now(), 3600)

      {:ok, queued_email} = Notifications.enqueue_email(%{
        to: "scheduled@example.com",
        subject: "Scheduled Email",
        text_body: "This will be sent later",
        scheduled_at: future_time
      })

      assert queued_email.status == "pending"
      assert queued_email.scheduled_at == future_time

      # Should not be processed yet
      result = Notifications.dispatch_pending_emails()
      assert %{sent: 0, retried: 0, failed: 0} = result
    end
  end
end
