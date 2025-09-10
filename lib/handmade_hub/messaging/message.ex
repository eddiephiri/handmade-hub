defmodule HandmadeHub.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :subject, :string
    field :body, :string
    field :read_at, :utc_datetime

    belongs_to :sender, HandmadeHub.Accounts.User
    belongs_to :recipient, HandmadeHub.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender_id, :recipient_id, :subject, :body, :read_at])
    |> validate_required([:sender_id, :recipient_id, :body])
    |> validate_length(:subject, max: 200)
  end
end
