defmodule HandmadeHub.Admins do
  @moduledoc """
  The Admins context, responsible for Admin users and their sessions.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Admins.Admin
  alias HandmadeHub.Admins.AdminToken

  # CRUD
  def get_admin!(id), do: Repo.get!(Admin, id)
  def get_admin_by_email(email) when is_binary(email), do: Repo.get_by(Admin, email: email)

  def list_admins(opts \\ []) do
    search = Keyword.get(opts, :search)
    Admin
    |> then(fn q ->
      if search && String.trim(search) != "" do
        like = "%#{search}%"
        where(q, [a], ilike(a.email, ^like) or ilike(a.username, ^like))
      else
        q
      end
    end)
    |> order_by([a], asc: a.inserted_at)
    |> Repo.all()
  end

  def register_admin(attrs) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> Repo.insert()
  end

  def change_admin_registration(%Admin{} = admin, attrs \\ %{}) do
    Admin.registration_changeset(admin, attrs, hash_password: false)
  end

  def change_admin_email(%Admin{} = admin, attrs \\ %{}) do
    Admin.email_changeset(admin, attrs)
  end

  def change_admin_password(%Admin{} = admin, attrs \\ %{}) do
    Admin.password_changeset(admin, attrs)
  end

  def update_admin(%Admin{} = admin, attrs) do
    admin |> Admin.edit_changeset(attrs) |> Repo.update()
  end

  def delete_admin(%Admin{} = admin) do
    # Prevent deleting the last super_admin
    if admin.role == "super_admin" do
      count = Repo.aggregate(from(a in Admin, where: a.role == "super_admin" and a.id != ^admin.id), :count)
      if count == 0 do
        {:error, :cannot_delete_last_super_admin}
      else
        Repo.delete(admin)
      end
    else
      Repo.delete(admin)
    end
  end

  # Admin approval functions
  def approve_admin(%Admin{} = admin) do
    admin
    |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  def reject_admin(%Admin{} = admin) do
    # Rejection means deletion (can be changed to soft delete later)
    Repo.delete(admin)
  end

  def pending_admins do
    Admin
    |> where([a], is_nil(a.confirmed_at))
    |> order_by([a], asc: a.inserted_at)
    |> Repo.all()
  end

  def approved_admins do
    Admin
    |> where([a], not is_nil(a.confirmed_at))
    |> order_by([a], asc: a.inserted_at)
    |> Repo.all()
  end

  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = Repo.get_by(Admin, email: email)
    if Admin.valid_password?(admin, password), do: admin
  end

  ## Sessions
  def generate_admin_session_token(admin) do
    {token, admin_token} = AdminToken.build_session_token(admin)
    Repo.delete_all(AdminToken.by_admin_and_contexts_query(admin, ["session"]))
    Repo.insert!(admin_token)
    token
  end

  def get_admin_by_session_token(token) do
    {:ok, query} = AdminToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def delete_admin_session_token(token) do
    Repo.delete_all(AdminToken.by_token_and_context_query(token, "session"))
    :ok
  end
end
