defmodule SM.Competitions do
  @moduledoc """
  The Competitions context.
  """
  use SM, :context

  alias SM.Competitions.Competition

  @doc """
  Returns the list of competitions.

  ## Examples

      iex> list()
      [%Competition{}, ...]

  """
  @spec list :: [Competition.t()]
  def list do
    Competition
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single Competition.

  ## Examples

  iex> get(123)
  {:ok, %Competition{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Competition.t()}
  def get(id) do
    case Repo.get(Competition, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a competition.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Competition{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(%{String.t() => any()}) :: {:error, any()} | {:ok, Competition.t()}
  def create(attrs \\ %{}) do
    %Competition{}
    |> Competition.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:competition, :created])
  end

  @doc """
  Updates a competition.

  ## Examples

      iex> update(competition, %{"field" => "new_value"})
      {:ok, %Competition{}}

      iex> update(competition, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Competition.t(), %{String.t() => any()}) ::
          {:ok, Competition.t()} | {:error, any()}
  def update(%Competition{} = competition, attrs) do
    competition
    |> Competition.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:competition, :updated])
  end

  @doc """
  Deletes a Competition.

  ## Examples

      iex> delete(competition)
      {:ok, %Competition{}}

      iex> delete(competition)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Competition.t()) :: {:ok, Competition.t()} | {:error, any()}
  def delete(%Competition{} = competition) do
    competition
    |> Repo.delete()
    |> notify_subscribers([:competition, :deleted])
  end

  @doc """
  Deletes many Competitions by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Competition, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:competition, :deleted])
    else
      notify_subscribers(:error, [:competition, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking competition changes.

  ## Examples

  iex> change(competition)
  %Ecto.Changeset{source: %Competition{}}

  """
  @spec change(Competition.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Competition{} = competition, params \\ %{}) do
    Competition.changeset(competition, params)
  end
end
