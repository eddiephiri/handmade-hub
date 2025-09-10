defmodule HandmadeHub.Repo.Migrations.UniqueSingleSessionPerUser do
  use Ecto.Migration

  def up do
    # Remove duplicate session tokens, keeping the newest (highest id)
    execute """
    DELETE FROM users_tokens a
    USING users_tokens b
    WHERE a.user_id = b.user_id
      AND a.context = 'session'
      AND b.context = 'session'
      AND a.id < b.id
    """

    create unique_index(:users_tokens, [:user_id, :context],
      where: "context = 'session'",
      name: :users_tokens_user_id_session_context_unique
    )
  end

  def down do
    drop_if_exists index(:users_tokens, [:user_id, :context], name: :users_tokens_user_id_session_context_unique)
  end
end
