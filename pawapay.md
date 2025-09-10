You are an AI agent tasked with integrating pawaPay's payment page for mobile money payments. Follow these steps:

Setup Authentication: Use bearer token authentication with the API token from pawaPay Dashboard. Set base URL to https://api.sandbox.pawapay.io for testing or https://api.pawapay.io for production.

Generate Payment Page: Make a POST request to /v2/paymentpage with:

depositId: Generate a unique UUIDv4 for tracking
returnUrl: Your callback URL where customers return after payment
reason: Description of what customer is paying for (optional)
amountDetails: Object with amount and currency (optional - if not provided, customer can enter amount)
phoneNumber: Customer's phone number (optional - if not provided, customer can enter)
country: ISO 3166-1 alpha-3 country code (optional)
Redirect Customer: Take the redirectUrl from the response and redirect the customer to this URL to complete payment.

Handle Return: When customer completes payment, they'll be redirected to your returnUrl with the original depositId as a query parameter.

Check Payment Status: Either wait for callback (if configured) or poll the /v2/deposits/{depositId} endpoint to get final payment status.

Error Handling: Handle potential errors like invalid parameters, authentication failures, or provider unavailability.

Always store the depositId before making the API call for proper reconciliation. The payment page handles the entire customer experience including provider selection and payment authorization.