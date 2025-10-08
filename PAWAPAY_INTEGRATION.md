# pawaPay Payment Gateway Integration Guide

This document provides setup and usage instructions for the pawaPay payment gateway integration in HandmadeHub.

## Overview

The pawaPay integration provides:
- **Deposits**: Customer payments for orders via mobile money
- **Payouts**: Automated scheduled payments to artisans
- **Refunds**: Admin-initiated refunds to customers
- **Unified callback handler** for all transaction types

## Environment Variables

Configure the following environment variables in production:

```bash
# Required
PAWAPAY_API_TOKEN=your_api_token_here

# Optional (defaults shown)
PAWAPAY_BASE_URL=https://api.sandbox.pawapay.io  # Use https://api.pawapay.io for production
PAWAPAY_CALLBACK_URL=https://yourdomain.com/api/pawapay/callback
```

### Development Setup

For development, add these to your environment:

```bash
export PAWAPAY_API_TOKEN="your_sandbox_token"
export PAWAPAY_BASE_URL="https://api.sandbox.pawapay.io"
export PAWAPAY_CALLBACK_URL="http://localhost:4000/api/pawapay/callback"
```

## Database Setup

Run migrations to create required tables:

```bash
mix ecto.migrate
```

This creates:
- `pawapay_transactions` - All payment transactions
- `artisan_payouts` - Payout batches to artisans
- `payout_settings` - Configuration for payout schedules
- Adds `pawapay_deposit_id` to orders table

## Callback Configuration

Configure the callback URL in your pawaPay dashboard:

1. Log into [pawaPay Dashboard](https://dashboard.pawapay.io)
2. Navigate to Settings → Webhooks
3. Set callback URL to: `https://yourdomain.com/api/pawapay/callback`
4. Use the same URL for all callback types (Deposits, Payouts, Refunds)

The unified callback handler automatically routes to appropriate processors based on the callback payload.

## Features

### 1. Customer Deposits (Order Payments)

When customers place orders:
1. Order is created in the database
2. Deposit transaction is initiated via pawaPay
3. Customer is redirected to pawaPay payment page
4. After payment, customer returns to your site
5. Callback from pawaPay updates order status
6. Order marked as "paid" when callback confirms payment

### 2. Artisan Payouts

#### Automated Scheduled Payouts

Configure in Admin → Payment Settings:
- **Schedule Type**: Weekly or Monthly
- **Schedule Day**: Day of week (1-7) or day of month (1-31)
- **Minimum Amount**: Minimum earnings for payout (default: ZMW 50)
- **Platform Fee**: Percentage deducted (default: 10%)

The scheduler runs:
- **Weekly**: Every Monday at 9:00 AM UTC (configurable in `config/config.exs`)
- Processes payouts for artisans who meet the minimum threshold
- Automatically creates payout records and initiates transfers

#### Manual Payouts

Admins can trigger manual payouts:
1. Go to Admin → Payouts
2. Click "Run Scheduled Payouts" to process all eligible artisans
3. Or trigger individual artisan payouts

### 3. Refunds

Admins can initiate refunds:
1. Go to Admin → Orders
2. Find the order to refund
3. Click "Initiate Refund"
4. Enter refund reason
5. System creates refund request to pawaPay
6. Callback updates order to "refunded" status

## Admin Interfaces

### Transactions Page (`/admin/transactions`)

View all pawaPay transactions:
- Filter by type (deposit/payout/refund)
- Filter by status (pending/completed/failed)
- View amounts, dates, and related orders/payouts
- Full transaction history

### Payouts Page (`/admin/payouts`)

Manage artisan payouts:
- View all payout batches
- Filter by status
- See gross amount, platform fee, and net amount
- Trigger manual payout processing
- View payout periods and order counts

### Payment Settings (`/admin/payment-settings`)

Configure system:
- Payout schedule (weekly/monthly)
- Minimum payout threshold
- Platform fee percentage
- Enable/disable automatic payouts
- View pawaPay configuration

## API Endpoints

### Webhook Callback

```
POST /api/pawapay/callback
```

Receives callbacks from pawaPay for all transaction types. Returns 200 OK to acknowledge receipt.

## Code Structure

### Core Modules

- **`HandmadeHub.Payments`** - Main payment context
- **`HandmadeHub.Payments.PawapayClient`** - HTTP client for pawaPay API
- **`HandmadeHub.Payments.Earnings`** - Earnings calculation logic
- **`HandmadeHub.Payments.PayoutScheduler`** - Automated payout processing
- **`HandmadeHubWeb.PawapayWebhookController`** - Callback handler

### Database Schemas

- **`HandmadeHub.Payments.PawapayTransaction`** - Transaction records
- **`HandmadeHub.Payments.ArtisanPayout`** - Payout batches
- **`HandmadeHub.Payments.PayoutSettings`** - Configuration

## Testing

### Test Environment

Use pawaPay sandbox for testing:
- Set `PAWAPAY_BASE_URL=https://api.sandbox.pawapay.io`
- Use sandbox API token
- Test callbacks using pawaPay's test tools

### Manual Testing

1. **Test Deposit**:
   - Create an order as a customer
   - Complete checkout with mobile money
   - Verify redirect to pawaPay
   - Complete test payment
   - Verify callback updates order status

2. **Test Payout**:
   - Configure payout settings
   - Trigger manual payout processing
   - Verify payout creation and API call
   - Check callback handling

3. **Test Refund**:
   - Create a paid order
   - Initiate refund from admin
   - Verify refund API call
   - Check callback updates order

## Troubleshooting

### Callback Not Received

1. Verify callback URL is publicly accessible
2. Check pawaPay dashboard webhook configuration
3. Review application logs for errors
4. Ensure endpoint returns 200 OK

### Payout Not Processing

1. Check artisan has minimum earnings threshold
2. Verify schedule day configuration
3. Check artisan phone number format
4. Review payout settings are active

### Failed Transactions

1. Check Admin → Transactions for error messages
2. Review `provider_response` field
3. Verify API token is valid
4. Check account balance (for payouts)

## Production Deployment

1. Set environment variables:
   ```bash
   PAWAPAY_API_TOKEN=production_token
   PAWAPAY_BASE_URL=https://api.pawapay.io
   PAWAPAY_CALLBACK_URL=https://yourdomain.com/api/pawapay/callback
   ```

2. Run migrations:
   ```bash
   mix ecto.migrate
   ```

3. Configure callback URL in pawaPay dashboard

4. Set initial payout settings via Admin interface

5. Test with small transactions first

6. Monitor transactions and logs

## Security Considerations

- API tokens are stored in environment variables (never in code)
- Callbacks validate transaction IDs before processing
- All refunds require admin authentication
- Transaction records include full audit trail
- Platform fees are calculated server-side

## Support

For pawaPay API documentation: https://docs.pawapay.io

For issues with this integration, check:
1. Application logs
2. Admin → Transactions page for error details
3. pawaPay dashboard for account status

