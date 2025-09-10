defmodule HandmadeHub.Messaging do
  @moduledoc """
  Simple in-app messaging between users.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Messaging.Message

  def send_message(%{sender_id: s, recipient_id: r, body: b} = attrs) when is_integer(s) and is_integer(r) and is_binary(b) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def list_conversations(user_id) do
    # Return latest message per user pair (other party) with counts
    sub =
      from m in Message,
        where: m.sender_id == ^user_id or m.recipient_id == ^user_id,
        select: %{other_id: fragment("CASE WHEN ? = ? THEN ? ELSE ? END", m.sender_id, ^user_id, m.recipient_id, m.sender_id),
                  message_id: m.id,
                  inserted_at: m.inserted_at}

    latest =
      from s in subquery(sub),
        group_by: s.other_id,
        select: %{other_id: s.other_id, last_message_id: max(s.message_id), last_at: max(s.inserted_at)}

    query_pairs =
      from l in subquery(latest),
        join: m in Message, on: m.id == l.last_message_id,
        order_by: [desc: l.last_at],
        select: %{other_id: l.other_id, message_id: m.id}

    pairs = Repo.all(query_pairs)

    message_ids = pairs |> Enum.map(& &1.message_id) |> Enum.uniq()
    messages = Repo.all(from m in Message, where: m.id in ^message_ids)
    messages_by_id = Map.new(messages, &{&1.id, &1})

    Enum.map(pairs, fn pair ->
      %{other_id: pair.other_id, last_message: Map.fetch!(messages_by_id, pair.message_id)}
    end)
  end

  def list_messages(user_id, other_user_id) do
    Repo.all(
      from m in Message,
        where: (m.sender_id == ^user_id and m.recipient_id == ^other_user_id) or
               (m.sender_id == ^other_user_id and m.recipient_id == ^user_id),
        order_by: [asc: m.inserted_at]
    )
  end

  def mark_read(user_id, other_user_id) do
    from(m in Message,
      where: m.recipient_id == ^user_id and m.sender_id == ^other_user_id and is_nil(m.read_at)
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  end

  def unread_count(user_id) do
    Repo.one(
      from m in Message,
        where: m.recipient_id == ^user_id and is_nil(m.read_at),
        select: count(m.id)
    ) || 0
  end
end
