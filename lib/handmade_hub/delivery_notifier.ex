defmodule HandmadeHub.DeliveryNotifier do
  import Swoosh.Email

  alias HandmadeHub.Mailer
  alias HandmadeHub.Notifications
  alias HandmadeHub.Delivery.Assignment

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"HandmadeHub", "noreply@handmadehub.com"})
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        {:ok, email}

      {:error, reason} ->
        _ = Notifications.enqueue_email(%{
          to: recipient,
          subject: subject,
          text_body: body,
          type: "delivery_notification",
          scheduled_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        {:error, reason}
    end
  end

  @doc """
  Notifies a rider about a new assignment.
  """
  def deliver_assignment_notification(%Assignment{} = assignment) do
    rider = assignment.rider
    order = assignment.order
    address = order.shipping_address

    deliver(
      construct_rider_email(rider),
      "New Delivery Assignment - #{order.order_number}",
      """
      ==============================

      Hi #{rider.name},

      You have been assigned a new delivery:

      Order Number: #{order.order_number}
      Customer: #{order.customer_name}

      Delivery Address:
      #{address.recipient_name}
      #{address.address_line_1}
      #{if address.address_line_2, do: address.address_line_2 <> "\n", else: ""}
      #{address.city}, #{address.province}

      Phone: #{address.phone_number}

      Please contact the customer at #{address.phone_number} before delivery.

      If you have any questions, please contact Handmade Hub support.

      ==============================
      """
    )
  end

  @doc """
  Notifies customer about delivery status updates.
  """
  def deliver_status_update(%Assignment{} = assignment) do
    rider = assignment.rider
    order = assignment.order

    case assignment.status do
      "in_transit" ->
        deliver(
          construct_customer_email(order),
          "Your order is on the way!",
          """
          ==============================

          Hi #{order.customer_name},

          Great news! Your order #{order.order_number} is now on the way to you.

          Your delivery rider: #{rider.name}
          Contact: #{rider.phone_number}

          Please ensure someone is available to receive the delivery.

          ==============================
          """
        )

      "delivered" ->
        deliver(
          construct_customer_email(order),
          "Your order has been delivered!",
          """
          ==============================

          Hi #{order.customer_name},

          Your order #{order.order_number} has been successfully delivered!

          We hope you enjoy your handmade products!

          Thank you for shopping with Handmade Hub.

          ==============================
          """
        )

      _ ->
        :ok
    end
  end

  defp construct_rider_email(rider) do
    # For now, we'll use a placeholder email since riders don't have emails
    # In production, you'd add an email field to the delivery_riders table
    "rider.#{rider.id}@handmadehub.local"
  end

  defp construct_customer_email(order) do
    order.customer_email || (order.user && order.user.email)
  end
end
