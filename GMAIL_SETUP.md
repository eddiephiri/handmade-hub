# Gmail Setup for HandmadeHub Email Delivery

This guide will help you set up Gmail to send real emails from your HandmadeHub application.

## Prerequisites

- A Gmail account (eddiephiri44@gmail.com)
- 2-Factor Authentication enabled on your Gmail account

## Step 1: Enable 2-Factor Authentication

1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Click on "2-Step Verification"
3. Follow the prompts to enable 2FA (if not already enabled)

## Step 2: Generate App Password

1. Go back to [Google Account Security](https://myaccount.google.com/security)
2. Find "App passwords" (only visible if 2FA is enabled)
3. Click "App passwords"
4. Select "Mail" as the app type
5. Select "Other (custom name)" as the device
6. Enter "HandmadeHub Development" as the name
7. Click "Generate"
8. **Copy the 16-character password** (e.g., `abcd efgh ijkl mnop`)

## Step 3: Configure Environment Variables

### Windows (Command Prompt):
```cmd
set GMAIL_USERNAME=eddiephiri44@gmail.com
set GMAIL_APP_PASSWORD=your-16-character-app-password
```

### Windows (PowerShell):
```powershell
$env:GMAIL_USERNAME="eddiephiri44@gmail.com"
$env:GMAIL_APP_PASSWORD="your-16-character-app-password"
```

### Linux/Mac:
```bash
export GMAIL_USERNAME="eddiephiri44@gmail.com"
export GMAIL_APP_PASSWORD="your-16-character-app-password"
```

## Step 4: Update Configuration

Replace your current `config/dev.exs` with the Gmail configuration:

```bash
# Backup your current dev.exs
cp config/dev.exs config/dev.exs.backup

# Use the Gmail configuration
cp config/dev_email.exs config/dev.exs
```

## Step 5: Test Email Delivery

1. **Start your Phoenix server:**
   ```bash
   mix phx.server
   ```

2. **Test email delivery:**
   ```bash
   mix run test_gmail_email.exs
   ```

3. **Check your inbox** at eddiephiri44@gmail.com

## Step 6: Test User Registration

1. Go to `http://localhost:4000/users/register`
2. Register with `eddiephiri44@gmail.com`
3. Check your email for the confirmation link
4. Click the confirmation link to verify your account

## Troubleshooting

### Common Issues:

1. **"Invalid credentials" error:**
   - Double-check your app password
   - Make sure 2FA is enabled
   - Regenerate the app password

2. **"Less secure app access" error:**
   - This shouldn't happen with app passwords
   - Make sure you're using the app password, not your regular password

3. **"Connection refused" error:**
   - Check your internet connection
   - Verify the SMTP settings (smtp.gmail.com:587)

4. **Emails not received:**
   - Check your spam folder
   - Verify the email address is correct
   - Check Gmail's "All Mail" folder

### Security Notes:

- **Never commit app passwords to version control**
- **Use environment variables for sensitive data**
- **App passwords are safer than regular passwords**
- **You can revoke app passwords anytime from Google Account settings**

## Alternative: Use Development Mailbox

If you prefer to keep using the local mailbox for development:

1. Keep your current `config/dev.exs` unchanged
2. View emails at `http://localhost:4000/dev/mailbox`
3. This is the recommended approach for development

## Production Configuration

For production, consider using:
- **SendGrid** (recommended)
- **Mailgun**
- **Amazon SES**
- **Postmark**

These services are more reliable and have better deliverability than Gmail SMTP.
