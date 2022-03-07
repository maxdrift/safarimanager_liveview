defmodule SM.Accounts.User do
  @moduledoc """
  User account schema
  """
  use SM, :schema

  alias SM.Organizations.Organization

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :first_name, :string
    field :last_name, :string
    belongs_to :organization, Organization

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

  * `:hash_password` - Hashes the password so it can be stored securely
  in the database and ensures the password field is cleared to prevent
  leaks in the logs. If password hashing is not needed and clearing the
  password field is not desired (like when using this changeset for
  validations on a LiveView form), this option can be set to `false`.
  Defaults to `true`.
  """
  @spec registration_changeset(User.t(), %{(String.t() | atom()) => any()}, Keyword.t()) ::
          Ecto.Changeset.t()
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password(opts)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, SM.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for registration during Competition organization.
  """
  @spec competition_registration_changeset(User.t(), %{(String.t() | atom()) => any()}) ::
          Ecto.Changeset.t()
  def competition_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name])
    |> validate_required([:first_name])
    |> put_email()
    |> put_default_password()
  end

  # TODO: Remove in Production!
  defp put_email(changeset) do
    first_name = get_field(changeset, :first_name)
    last_name = get_field(changeset, :last_name)

    full_name =
      [first_name, last_name]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.map_join(".", &String.downcase/1)

    put_change(changeset, :email, "#{full_name}@maxdrift.org")
  end

  defp put_default_password(changeset) do
    changeset
    |> cast(%{password: SM.DefaultPassword.generate()}, [:password])
    |> validate_password([])
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  @spec email_changeset(User.t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

  * `:hash_password` - Hashes the password so it can be stored securely
  in the database and ensures the password field is cleared to prevent
  leaks in the logs. If password hashing is not needed and clearing the
  password field is not desired (like when using this changeset for
  validations on a LiveView form), this option can be set to `false`.
  Defaults to `true`.
  """
  @spec password_changeset(User.t(), %{(String.t() | atom()) => any()}, Keyword.t()) ::
          Ecto.Changeset.t()
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  @spec confirm_changeset(User.t()) :: Ecto.Changeset.t()
  def confirm_changeset(user) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  @spec valid_password?(User.t(), String.t()) :: boolean
  def valid_password?(%SM.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_user, _password) do
    Bcrypt.no_user_verify()
    false
  end

  @spec validate_current_password(Ecto.Changeset.t(), String.t()) :: Ecto.Changeset.t()
  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
