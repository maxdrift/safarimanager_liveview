defmodule SM.Jurors do
  @moduledoc """
  The Jurors context.
  """
  use SM, :context

  alias SM.Jurors.Juror

  @doc """
  Returns the list of jurors.

  ## Examples

      iex> list()
      [%Juror{}, ...]

  """
  @spec list :: [Juror.t()]
  def list do
    Juror
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single Juror.

  ## Examples

  iex> get(123)
  {:ok, %Juror{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Juror.t()}
  def get(id) do
    case Repo.get(Juror, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a juror.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Juror{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Juror.t()}
  def create(attrs \\ %{}) do
    %Juror{}
    |> Juror.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Import a juror.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Juror{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Juror.t()}
  def import(attrs \\ %{}) do
    %Juror{}
    |> Juror.import_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Updates a juror.

  ## Examples

      iex> update(juror, %{"field" => "new_value"})
      {:ok, %Juror{}}

      iex> update(juror, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Juror.t(), %{String.t() => any()}) ::
          {:ok, Juror.t()} | {:error, any()}
  def update(%Juror{} = juror, attrs) do
    juror
    |> Juror.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Deletes a Juror.

  ## Examples

      iex> delete("id1", "id2")
      {:ok, %Juror{}}

      iex> delete("id1", "id2")
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(String.t(), String.t()) :: {:ok, Juror.t()} | {:error, any()}
  def delete(user_id, competition_id) do
    Juror
    |> Repo.get_by!(user_id: user_id, competition_id: competition_id)
    |> Repo.delete()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Deletes many Jurors by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from(entity in Juror, where: entity.id in ^ids))

    if deleted == Enum.count(ids) do
      with {:ok, _result} <-
             notify_subscribers({:ok, deleted}, [:competition, :updated], id_key: :competition_id),
           do: notify_subscribers({:ok, deleted}, [:user, :updated], id_key: :user_id)
    else
      with {:ok, _result} <-
             notify_subscribers(:error, [:competition, :updated], id_key: :competition_id),
           do: notify_subscribers(:error, [:user, :updated], id_key: :user_id)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking juror changes.

  ## Examples

  iex> change(juror)
  %Ecto.Changeset{source: %Juror{}}

  """
  @spec change(Juror.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Juror{} = juror, params \\ %{}) do
    Juror.changeset(juror, params)
  end
end
