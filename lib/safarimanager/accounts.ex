defmodule SM.Accounts do
  @moduledoc """
  The Accounts context.
  """

  use SM, :context

  alias SM.Accounts.User
  alias SM.Accounts.UserNotifier
  alias SM.Accounts.UserToken
  alias SM.Jurors.Juror
  alias SM.Participants.Participant

  ## Database getters

  @doc """
  Returns the list of users.

  ## Examples

      iex> list()
      [%User{}, ...]

  """
  @spec list :: [User.t()]
  def list do
    User
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> Repo.preload([:organization, :category])
  end

  @doc """
  Returns the list of users who are not
  participants or jurors of a specific Competition.

  SQL query:
    select *
      from users u
        left join participants p
          on p.user_id = u.id and p.competition_id = '<competition-id>'
      where p.user_id is null;

  ## Examples

      iex> list_enrollable("competition_id")
      [%User{}, ...]

  """
  @spec list_enrollable(String.t()) :: [User.t()]
  def list_enrollable(competition_id) do
    query =
      from(
        u in User,
        where: not is_nil(u.category_id),
        left_join: p in Participant,
        on: p.user_id == u.id and p.competition_id == ^competition_id,
        where: is_nil(p.user_id),
        left_join: j in Juror,
        on: j.user_id == u.id and j.competition_id == ^competition_id,
        where: is_nil(j.user_id),
        left_join: o in assoc(u, :organization),
        on: o.id == u.organization_id,
        order_by: [desc: :inserted_at],
        preload: [:organization, :category]
      )

    Repo.all(query)
  end

  @doc """
  Filter enrollable by name
  """
  @spec list_enrollable(String.t(), String.t()) :: [User.t()]
  def list_enrollable(competition_id, name) do
    pattern = "%#{name}%"

    query =
      from(
        u in User,
        where: not is_nil(u.category_id),
        left_join: p in Participant,
        on: p.user_id == u.id and p.competition_id == ^competition_id,
        where: is_nil(p.user_id),
        left_join: j in Juror,
        on: j.user_id == u.id and j.competition_id == ^competition_id,
        where: is_nil(j.user_id),
        left_join: o in assoc(u, :organization),
        on: o.id == u.organization_id,
        where:
          fragment(@like_fragment, u.first_name, ^pattern) or
            fragment(@like_fragment, u.last_name, ^pattern),
        order_by: [desc: :inserted_at],
        preload: [:organization, :category]
      )

    Repo.all(query)
  end

  @doc """
  Filter enrollable Jurors by name
  """
  @spec list_enrollable_jurors(String.t()) :: [User.t()]
  def list_enrollable_jurors(competition_id) do
    query =
      from(
        u in User,
        left_join: p in Participant,
        on: p.user_id == u.id and p.competition_id == ^competition_id,
        where: is_nil(p.user_id),
        left_join: j in Juror,
        on: j.user_id == u.id and j.competition_id == ^competition_id,
        where: is_nil(j.user_id),
        left_join: o in assoc(u, :organization),
        on: o.id == u.organization_id,
        order_by: [desc: :inserted_at],
        preload: [:organization, :category]
      )

    Repo.all(query)
  end

  @doc """
  Filter enrollable Jurors by name
  """
  @spec list_enrollable_jurors(String.t(), String.t()) :: [User.t()]
  def list_enrollable_jurors(competition_id, name) do
    pattern = "%#{name}%"

    query =
      from(
        u in User,
        left_join: p in Participant,
        on: p.user_id == u.id and p.competition_id == ^competition_id,
        where: is_nil(p.user_id),
        left_join: j in Juror,
        on: j.user_id == u.id and j.competition_id == ^competition_id,
        where: is_nil(j.user_id),
        left_join: o in assoc(u, :organization),
        on: o.id == u.organization_id,
        where:
          fragment(@like_fragment, u.first_name, ^pattern) or
            fragment(@like_fragment, u.last_name, ^pattern),
        order_by: [desc: :inserted_at],
        preload: [:organization, :category]
      )

    Repo.all(query)
  end

  @doc """
  Gets a user by email.

  ## Examples

  iex> get_user_by_email("foo@example.com")
  %User{}

  iex> get_user_by_email("unknown@example.com")
  nil

  """
  @spec get_user_by_email(String.t()) :: User.t()
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

  iex> get_user_by_email_and_password("foo@example.com", "correct_password")
  %User{}

  iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
  nil

  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: User.t()
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

  iex> get_user!(123)
  %User{}

  iex> get_user!(456)
  ** (Ecto.NoResultsError)

  """
  @spec get_user!(String.t()) :: User.t()
  def get_user!(id) do
    User
    |> Repo.get!(id)
    |> Repo.preload([:category])
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

  iex> get_user!(123)
  %User{}

  iex> get_user!(456)
  ** (Ecto.NoResultsError)

  """
  @spec get_user(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, Repo.preload(user, [:organization, :category])}
    end
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:user, :created])
  end

  @doc """
  Registers a user by name and optional email.
  """
  def register_simplified_user(attrs) do
    %User{}
    |> User.competition_registration_changeset(attrs)
    # TODO: Remove in Production!
    |> User.maybe_put_email()
    |> Repo.insert()
    |> notify_subscribers([:user, :created])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user name and email.

  ## Examples

      iex> change_for_competition_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_for_competition_registration(user, attrs \\ %{}) do
    User.competition_registration_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates a user.

  ## Examples

  iex> update(user, %{"field" => "new_value"})
  {:ok, %User{}}

  iex> update(user, %{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec update(User.t(), %{String.t() => any()}) ::
          {:ok, User.t()} | {:error, any()}
  def update(%User{} = user, attrs) do
    user
    |> User.competition_registration_changeset(attrs)
    |> User.maybe_put_email()
    |> Repo.update()
    |> notify_subscribers([:user, :updated])
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  @spec update_user_email(User.t(), String.t()) :: :ok | :error
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _result -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, fn token -> url(~p"/users/settings/confirm_email/\#{token}") end)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a User.

  ## Examples

  iex> delete(user)
  {:ok, %User{}}

  iex> delete(user)
  {:error, %Ecto.Changeset{}}

  """
  @spec delete(User.t()) :: {:ok, User.t()} | {:error, any()}
  def delete(%User{} = user) do
    user
    |> Repo.delete()
    |> notify_subscribers([:user, :deleted])
  end

  @doc """
  Deletes many Users by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in User, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:user, :deleted])
    else
      notify_subscribers(:error, [:user, :deleted])
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, fn token -> url(~p"/users/confirm/\#{token}") end)
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, fn token -> url(~p"/users/confirm/\#{token}") end)
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _result -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, fn token -> url(~p"/users/reset_password/\#{token}") end)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _result -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _changes} -> {:error, changeset}
    end
  end
end
