defmodule HandmadeHub.Notifications.EmailQueue do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ["pending", "sent", "failed"]

  schema "email_queue" do
    field :to, :string
    field :reply_to, :string
    field :subject, :string
    field :text_body, :string
    field :type, :string, default: "generic"
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 5
    field :last_error, :string
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(queue, attrs) do
    queue
    |> cast(attrs, [
      :to,
      :reply_to,
      :subject,
      :text_body,
      :type,
      :status,
      :attempts,
      :max_attempts,
      :last_error,
      :scheduled_at,
      :sent_at
    ])
    |> validate_required([:to, :subject, :text_body, :type, :status, :scheduled_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_number(:max_attempts, greater_than: 0)
  end
end
