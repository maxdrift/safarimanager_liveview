defmodule SM.Evaluations do
  @moduledoc """
  The Evaluations context.
  """
  use SM, :context

  alias SM.Evaluations.Evaluation

  @doc """
  Returns the list of evaluation types.

  ## Examples

  iex> list_evaluation_types()
  [:numeric]

  """
  @spec list_evaluation_types :: [:numeric, ...]
  def list_evaluation_types do
    Evaluation.get_types()
  end

  @doc """
  Returns the list of evaluations.

  ## Examples

      iex> list()
      [%Evaluation{}, ...]

  """
  @spec list :: [Evaluation.t()]
  def list do
    Evaluation
    |> order_by(desc: :value)
    |> Repo.all()
  end

  @doc """
  Returns the list of evaluations by value.

  ## Examples

      iex> list_by_value("10")
      [%Evaluation{}, ...]

  """
  @spec list_by_value(Decimal.t()) :: [Evaluation.t()]
  def list_by_value(value) do
    Evaluation
    |> where(value: ^value)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of evaluations by list of IDs.

  ## Examples

      iex> list_by_ids(["foo", "bar", "baz"])
      [%Evaluation{}, ...]

  """
  @spec list_by_ids([String.t()]) :: [Evaluation.t()]
  def list_by_ids(ids) do
    query =
      from(
        e in Evaluation,
        where: e.id in ^ids,
        order_by: [asc: :value]
      )

    Repo.all(query)
  end

  @doc """
  Gets a single Evaluation.

  ## Examples

  iex> get(123)
  {:ok, %Evaluation{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Evaluation.t()}
  def get(id) do
    case Repo.get(Evaluation, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a evaluation.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Evaluation{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Evaluation.t()}
  def create(attrs \\ %{}) do
    %Evaluation{}
    |> Evaluation.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:evaluation, :created])
  end

  @doc """
  Import a evaluation.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Evaluation{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Evaluation.t()}
  def import(attrs \\ %{}) do
    %Evaluation{}
    |> Evaluation.import_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:evaluation, :created])
  end

  @doc """
  Updates a evaluation.

  ## Examples

      iex> update(evaluation, %{"field" => "new_value"})
      {:ok, %Evaluation{}}

      iex> update(evaluation, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Evaluation.t(), %{String.t() => any()}) ::
          {:ok, Evaluation.t()} | {:error, any()}
  def update(%Evaluation{} = evaluation, attrs) do
    evaluation
    |> Evaluation.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:evaluation, :updated])
  end

  @doc """
  Deletes a Evaluation.

  ## Examples

      iex> delete(evaluation)
      {:ok, %Evaluation{}}

      iex> delete(evaluation)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Evaluation.t()) :: {:ok, Evaluation.t()} | {:error, any()}
  def delete(%Evaluation{} = evaluation) do
    evaluation
    |> Repo.delete()
    |> notify_subscribers([:evaluation, :deleted])
  end

  @doc """
  Deletes many Evaluations by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from(entity in Evaluation, where: entity.id in ^ids))

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:evaluation, :deleted])
    else
      notify_subscribers(:error, [:evaluation, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking evaluation changes.

  ## Examples

  iex> change(evaluation)
  %Ecto.Changeset{source: %Evaluation{}}

  """
  @spec change(Evaluation.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Evaluation{} = evaluation, params \\ %{}) do
    Evaluation.changeset(evaluation, params)
  end
end
