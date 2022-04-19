defmodule SM.Participants do
  @moduledoc """
  The Participants context.
  """
  use SM, :context

  alias SM.Participants.Participant

  @doc """
  Returns the list of participants.

  ## Examples

      iex> list()
      [%Participant{}, ...]

  """
  @spec list :: [Participant.t()]
  def list do
    Participant
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of participants filtered by competition ID and name.

  ## Examples

      iex> list("123")
      [%Participant{}, ...]

  """
  @spec list(String.t()) :: [Participant.t()]
  def list(competition_id) do
    query =
      from(
        p in Participant,
        where: [competition_id: ^competition_id],
        inner_join: u in assoc(p, :user),
        left_join: o in assoc(u, :organization),
        order_by: [asc: u.last_name],
        preload: [user: {u, [organization: o]}]
      )

    Repo.all(query)
  end

  @doc """
  Returns the list of participants filtered by competition ID and name.

  ## Examples

      iex> list("123", "foo")
      [%Participant{}, ...]

  """
  @spec list(String.t(), String.t()) :: [Participant.t()]
  def list(competition_id, name) do
    pattern = "%#{name}%"

    query =
      from(
        p in Participant,
        where: [competition_id: ^competition_id],
        inner_join: u in assoc(p, :user),
        where:
          fragment(@like_fragment, u.first_name, ^pattern) or
            fragment(@like_fragment, u.last_name, ^pattern),
        left_join: o in assoc(u, :organization),
        order_by: [asc: u.last_name],
        preload: [user: {u, [organization: o]}]
      )

    Repo.all(query)
  end

  @doc """
  Gets a single Participant.

  ## Examples

  iex> get(123)
  {:ok, %Participant{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Participant.t()}
  def get(id) do
    case Repo.get(Participant, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a participant.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Participant{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Participant.t()}
  def create(attrs \\ %{}) do
    %Participant{}
    |> Participant.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Updates a participant.

  ## Examples

      iex> update(participant, %{"field" => "new_value"})
      {:ok, %Participant{}}

      iex> update(participant, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Participant.t(), %{String.t() => any()}) ::
          {:ok, Participant.t()} | {:error, any()}
  def update(%Participant{} = participant, attrs) do
    participant
    |> Participant.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Deletes a Participant.

  ## Examples

      iex> delete("id1", "id2")
      {:ok, %Participant{}}

      iex> delete("id1", "id2")
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(String.t(), String.t()) :: {:ok, Participant.t()} | {:error, any()}
  def delete(user_id, competition_id) do
    Participant
    |> Repo.get_by!(user_id: user_id, competition_id: competition_id)
    |> Repo.delete()
    |> notify_subscribers([:competition, :updated], id_key: :competition_id)
    |> notify_subscribers([:user, :updated], id_key: :user_id)
  end

  @doc """
  Deletes many Participants by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Participant, where: entity.id in ^ids)

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
  Returns an `%Ecto.Changeset{}` for tracking participant changes.

  ## Examples

  iex> change(participant)
  %Ecto.Changeset{source: %Participant{}}

  """
  @spec change(Participant.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Participant{} = participant, params \\ %{}) do
    Participant.changeset(participant, params)
  end
end
