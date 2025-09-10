defmodule HandmadeHub.Notifications do
  @moduledoc """
  Email notifications enqueueing and dispatching.
  """

  import Ecto.Query
  alias HandmadeHub.Repo
  alias HandmadeHub.Notifications.EmailQueue
  alias HandmadeHub.Mailer
  alias Swoosh.Email

  @doc """
  Enqueue an email to be sent later.

  Required attrs: :to, :subject, :text_body
  Optional: :type, :scheduled_at, :max_attempts
  """
  def enqueue_email(attrs) when is_map(attrs) do
    scheduled_at = Map.get(attrs, :scheduled_at) || Map.get(attrs, "scheduled_at") || now()

    attrs =
      attrs
      |> Map.put_new(:scheduled_at, scheduled_at)
      |> Map.put_new(:type, Map.get(attrs, :type) || Map.get(attrs, "type") || "generic")

    %EmailQueue{}
    |> EmailQueue.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Dispatches pending emails scheduled for now or earlier.
  Uses a simple exponential backoff on failures.
  """
  def dispatch_pending_emails do
    now = now()

    query =
      from eq in EmailQueue,
        where: eq.status == "pending" and eq.scheduled_at <= ^now,
        lock: "FOR UPDATE SKIP LOCKED",
        limit: 50

    emails = Repo.all(query)

    Enum.reduce(emails, %{sent: 0, failed: 0, retried: 0}, fn eq, acc ->
      case try_deliver(eq) do
        {:ok, _} -> %{acc | sent: acc.sent + 1}
        {:retry, _} -> %{acc | retried: acc.retried + 1}
        {:error, _} -> %{acc | failed: acc.failed + 1}
      end
    end)
  end

  defp try_deliver(%EmailQueue{} = eq) do
    email =
      Email.new()
      |> Email.to(eq.to)
      |> Email.from({"HandmadeHub", "contact@handmadehub.com"})
      |> maybe_reply_to(eq.reply_to)
      |> Email.subject(eq.subject)
      |> Email.text_body(eq.text_body)

    case Mailer.deliver(email) do
      {:ok, _} ->
        eq
        |> Ecto.Changeset.change(%{status: "sent", sent_at: now(), attempts: eq.attempts + 1, last_error: nil})
        |> Repo.update()
        {:ok, eq}

      {:error, reason} ->
        attempts = eq.attempts + 1
        if attempts >= eq.max_attempts do
          eq
          |> Ecto.Changeset.change(%{status: "failed", attempts: attempts, last_error: inspect(reason)})
          |> Repo.update()
          {:error, reason}
        else
          backoff_minutes = backoff_minutes(attempts)
          next_time = DateTime.add(now(), backoff_minutes * 60, :second)
          eq
          |> Ecto.Changeset.change(%{status: "pending", attempts: attempts, last_error: inspect(reason), scheduled_at: next_time})
          |> Repo.update()
          {:retry, reason}
        end
    end
  end

  defp maybe_reply_to(email, nil), do: email
  defp maybe_reply_to(email, ""), do: email
  defp maybe_reply_to(email, addr), do: Email.reply_to(email, addr)

  defp now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp backoff_minutes(attempts) do
    # 5, 10, 20, 40, 60, 60, ...
    min(60, trunc(:math.pow(2, max(attempts - 1, 0)) * 5))
  end
end
