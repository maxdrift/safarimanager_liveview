defmodule SM.Subjects do
  @moduledoc """
  The Subjects context.
  """
  use SM, :context

  alias SM.Subjects.Subject

  # @topic inspect(__MODULE__)

  # @spec subscribe() :: :ok | {:error, {:already_registered, pid()}}
  # def subscribe do
  #   Phoenix.PubSub.subscribe(SM.PubSub, @topic)
  # end

  # @spec subscribe(String.t()) :: :ok | {:error, {:already_registered, pid()}}
  # def subscribe(id) do
  #   Phoenix.PubSub.subscribe(SM.PubSub, @topic <> "#{id}")
  # end

  @doc """
  Returns the list of subject_types.

  ## Examples

  iex> list_subject_types()
  [%Type{}, ...]

  """
  @spec list_subject_types :: [:ambient | :fish | :fish_macro | :macro, ...]
  def list_subject_types do
    Subject.get_available_types()
  end

  @doc """
  Returns the list of subjects.

  ## Examples

      iex> list()
      [%Subject{}, ...]

  """
  @spec list :: [Subject.t()]
  def list do
    Subject
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single Subject.

  ## Examples

  iex> get(123)
  {:ok, %Subject{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Subject.t()}
  def get(id) do
    case Repo.get(Organization, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a subject.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Subject{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(%{String.t() => any()}) :: {:error, any()} | {:ok, Subject.t()}
  def create(attrs \\ %{}) do
    %Subject{}
    |> Subject.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:subject, :created])
  end

  @doc """
  Updates a subject.

  ## Examples

      iex> update(subject, %{field: new_value})
      {:ok, %Subject{}}

      iex> update(subject, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Subject.t(), %{String.t() => any()}) :: {:ok, Subject.t()} | {:error, any()}
  def update(%Subject{} = subject, attrs) do
    subject
    |> Subject.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:subject, :updated])
  end

  @doc """
  Deletes a Subject.

  ## Examples

      iex> delete(subject)
      {:ok, %Subject{}}

      iex> delete(subject)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Subject.t()) :: {:ok, Subject.t()} | {:error, any()}
  def delete(%Subject{} = subject) do
    subject
    |> Repo.delete()
    |> notify_subscribers([:subject, :deleted])
  end

  @doc """
  Deletes many Subjects by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Subject, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:subject, :deleted])
    else
      notify_subscribers(:error, [:subject, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subject changes.

  ## Examples

  iex> change(subject)
  %Ecto.Changeset{source: %Subject{}}

  """
  @spec change(Subject.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Subject{} = subject, params \\ %{}) do
    Subject.changeset(subject, params)
  end
end
