defmodule HandmadeHub.Admins.AdminToken do
  use Ecto.Schema
  import Ecto.Query
  alias HandmadeHub.Admins.AdminToken

  @hash_algorithm :sha256
  @rand_size 32

  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7

  schema "admins_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :admin, HandmadeHub.Admins.Admin

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def build_session_token(admin) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %AdminToken{token: token, context: "session", admin_id: admin.id}}
  end

  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: admin in assoc(token, :admin),
        where: token.inserted_at > ago(60, "minute"),
        select: admin

    {:ok, query}
  end

  def build_email_token(admin, context) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %AdminToken{token: hashed_token, context: context, sent_to: admin.email, admin_id: admin.id}}
  end

  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = case context do
          "confirm" -> @confirm_validity_in_days
          "reset_password" -> @reset_password_validity_in_days
        end

        query =
          from token in by_token_and_context_query(hashed_token, context),
            join: admin in assoc(token, :admin),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == admin.email,
            select: admin

        {:ok, query}
      :error -> :error
    end
  end

  def by_token_and_context_query(token, context) do
    from AdminToken, where: [token: ^token, context: ^context]
  end

  def by_admin_and_contexts_query(admin, contexts) do
    from t in AdminToken, where: t.admin_id == ^admin.id and t.context in ^contexts
  end
end
