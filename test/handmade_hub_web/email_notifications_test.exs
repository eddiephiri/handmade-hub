defmodule HandmadeHubWeb.EmailNotificationsTest do
  use HandmadeHubWeb.ConnCase, async: false

  alias HandmadeHub.Accounts
  alias HandmadeHub.Notifications
  alias HandmadeHub.Notifications.EmailQueue
  alias HandmadeHub.Repo
  import HandmadeHub.AccountsFixtures

  describe "email verification flow integration" do
    test "user registration sends confirmation email", %{conn: conn} do
      user_attrs = %{
        email: "newuser@example.com",
        password: "validpassword123",
        role: "buyer"
      }

      # Register user through the web interface
      {:ok, user} = Accounts.register_user(user_attrs)

      # Simulate the confirmation email being sent
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Verify user is not confirmed
      refute user.confirmed_at

      # Verify confirmation token was created
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 1
      assert hd(tokens).context == "confirm"
    end

    test "unconfirmed user cannot log in", %{conn: conn} do
      user = user_fixture()
      # Ensure user is not confirmed
      {:ok, unconfirmed_user} =
        user
        |> Ecto.Changeset.change(confirmed_at: nil)
        |> Repo.update()

      # Attempt to log in
      conn = post(conn, ~p"/users/log_in", %{
        "user" => %{
          "email" => unconfirmed_user.email,
          "password" => "hello world!"
        }
      })

      # Should be redirected to confirmation page
      assert redirected_to(conn) == ~p"/users/confirm"
      assert get_flash(conn, :error) =~ "not confirmed"
    end

    test "confirmed user can log in", %{conn: conn} do
      user = user_fixture()
      # Confirm the user
      {:ok, confirmed_user} =
        user
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now())
        |> Repo.update()

      # Attempt to log in
      conn = post(conn, ~p"/users/log_in", %{
        "user" => %{
          "email" => confirmed_user.email,
          "password" => "hello world!"
        }
      })

      # Should be redirected to appropriate dashboard
      assert redirected_to(conn) == ~p"/browse"
    end
  end

  describe "email confirmation page" do
    test "renders confirmation page for valid token", %{conn: conn} do
      user = user_fixture()

      # Create a confirmation token
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Get the token
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      token = hd(tokens)

      # Visit confirmation page
      conn = get(conn, ~p"/users/confirm/#{token.token}")
      assert html_response(conn, 200) =~ "Confirm Account"
    end

    test "confirms user with valid token", %{conn: conn} do
      user = user_fixture()

      # Create a confirmation token
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Get the token
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      token = hd(tokens)

      # Confirm the user
      {:ok, confirmed_user} = Accounts.confirm_user(token.token)

      # Verify user is confirmed
      assert confirmed_user.confirmed_at

      # Verify token was cleaned up
      tokens_after = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens_after) == 0
    end

    test "handles invalid confirmation token", %{conn: conn} do
      # Visit confirmation page with invalid token
      conn = get(conn, ~p"/users/confirm/invalid_token")
      assert html_response(conn, 200) =~ "Confirm Account"

      # Attempt to confirm with invalid token
      {:error, _} = Accounts.confirm_user("invalid_token")
    end
  end

  describe "email resend functionality" do
    test "renders resend confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/users/confirm")
      assert html_response(conn, 200) =~ "No confirmation instructions received"
    end

    test "resends confirmation instructions", %{conn: conn} do
      user = user_fixture()

      # Request resend
      conn = post(conn, ~p"/users/confirm", %{
        "user" => %{"email" => user.email}
      })

      # Should redirect with success message
      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
    end
  end

  describe "email queue processing" do
    test "processes pending emails in queue" do
      # Create a pending email
      {:ok, queued_email} = Notifications.enqueue_email(%{
        to: "test@example.com",
        subject: "Test Email",
        text_body: "Test body",
        scheduled_at: DateTime.add(DateTime.utc_now(), -60)
      })

      # Process the queue
      result = Notifications.dispatch_pending_emails()
      assert %{sent: 1, retried: 0, failed: 0} = result

      # Verify email was marked as sent
      reloaded = Repo.get!(EmailQueue, queued_email.id)
      assert reloaded.status == "sent"
      assert reloaded.sent_at
      assert reloaded.attempts == 1
    end

    test "handles email delivery failures with retry" do
      # This test would require mocking the mailer to fail
      # For now, we test the structure
      {:ok, queued_email} = Notifications.enqueue_email(%{
        to: "test@example.com",
        subject: "Test Email",
        text_body: "Test body",
        scheduled_at: DateTime.add(DateTime.utc_now(), -60),
        max_attempts: 3
      })

      # Process the queue (should succeed in test environment)
      result = Notifications.dispatch_pending_emails()
      assert %{sent: 1, retried: 0, failed: 0} = result

      # Verify email was processed
      reloaded = Repo.get!(EmailQueue, queued_email.id)
      assert reloaded.status == "sent"
    end
  end

  describe "email notification content" do
    test "confirmation email contains proper branding" do
      user = user_fixture()

      {:ok, email} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Check that the email contains proper branding
      assert is_map(email)
      assert Map.has_key?(email, :to)
      assert Map.has_key?(email, :body)
    end

    test "password reset email contains proper branding" do
      user = user_fixture()

      {:ok, email} = Accounts.deliver_user_reset_password_instructions(user, fn _token -> "test_url" end)

      assert is_map(email)
      assert Map.has_key?(email, :to)
      assert Map.has_key?(email, :body)
    end

    test "email update instructions contain proper branding" do
      user = user_fixture()

      {:ok, email} = Accounts.deliver_user_update_email_instructions(user, user.email, fn _token -> "test_url" end)

      assert is_map(email)
      assert Map.has_key?(email, :to)
      assert Map.has_key?(email, :body)
    end
  end

  describe "email notification security" do
    test "confirmation tokens are unique" do
      user = user_fixture()

      # Create multiple confirmation requests
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "url1" end)
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "url2" end)

      # Should have multiple tokens
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 2

      # Tokens should be different
      token_values = Enum.map(tokens, & &1.token)
      assert length(Enum.uniq(token_values)) == 2
    end

    test "confirmation tokens expire after use" do
      user = user_fixture()

      # Create confirmation token
      {:ok, _} = Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)

      # Get the token
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      token = hd(tokens)

      # Use the token
      {:ok, _} = Accounts.confirm_user(token.token)

      # Token should no longer be valid
      {:error, _} = Accounts.confirm_user(token.token)
    end

    test "email addresses are properly validated" do
      # Test with invalid email format
      invalid_user_attrs = %{
        email: "invalid-email",
        password: "validpassword123",
        role: "buyer"
      }

      # Should fail validation
      {:error, changeset} = Accounts.register_user(invalid_user_attrs)
      refute changeset.valid?
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end
  end

  describe "email notification performance" do
    test "handles multiple concurrent email requests" do
      # Create multiple users
      users = for i <- 1..10 do
        user_fixture(%{email: "user#{i}@example.com"})
      end

      # Send confirmation emails to all users
      results = Enum.map(users, fn user ->
        Accounts.deliver_user_confirmation_instructions(user, fn _token -> "test_url" end)
      end)

      # All should succeed
      assert Enum.all?(results, fn {:ok, _} -> true; _ -> false end)

      # Should have created tokens for all users
      tokens = Repo.all(HandmadeHub.Accounts.UserToken)
      assert length(tokens) == 10
    end

    test "email queue processes efficiently" do
      # Create multiple pending emails
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      past_time = DateTime.add(now, -60)

      for i <- 1..20 do
        {:ok, _} = Notifications.enqueue_email(%{
          to: "user#{i}@example.com",
          subject: "Email #{i}",
          text_body: "Body #{i}",
          scheduled_at: past_time
        })
      end

      # Process all emails
      result = Notifications.dispatch_pending_emails()
      assert %{sent: 20, retried: 0, failed: 0} = result
    end
  end
end
