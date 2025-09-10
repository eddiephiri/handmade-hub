defmodule HandmadeHub.Admins.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admins" do
    field :permissions, :map
    field :username, :string
    field :role, :string
    field :email, :string
    field :profile_image, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Registration changeset for admins.
  """
  def registration_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:email, :username, :password, :role, :permissions])
    |> validate_required([:email, :username, :password, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, HandmadeHub.Repo)
    |> unique_constraint(:email)
    |> unsafe_validate_unique(:username, HandmadeHub.Repo)
    |> unique_constraint(:username)
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 12, max: 72)
    |> validate_inclusion(:role, ["super_admin", "moderator", "support", "analyst"])
    |> maybe_hash_password(opts)
  end

  def password_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  def email_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, HandmadeHub.Repo)
    |> unique_constraint(:email)
  end

  def confirm_changeset(admin) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(admin, confirmed_at: now)
  end

  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])
    if valid_password?(changeset.data, password), do: changeset, else: add_error(changeset, :current_password, "is not valid")
  end

  def valid_password?(%HandmadeHub.Admins.Admin{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Changeset for editing admin fields (email, username, role, permissions).
  """
  def edit_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :username, :role, :permissions])
    |> validate_required([:email, :username, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, HandmadeHub.Repo)
    |> unique_constraint(:email)
    |> unsafe_validate_unique(:username, HandmadeHub.Repo)
    |> unique_constraint(:username)
    |> validate_length(:username, min: 3, max: 50)
    |> validate_inclusion(:role, ["super_admin", "moderator", "support", "analyst"])
  end
end
