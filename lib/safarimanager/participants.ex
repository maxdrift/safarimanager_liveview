defmodule SM.Participants do
  @moduledoc """
  The Participants context.
  """
  use SM, :context

  alias SM.Participants.Participant
  alias SM.Slides.Slide
  alias SM.Teams.TeamMember

  @doc """
  Returns the list of participants.

  ## Examples

      iex> list()
      [%Participant{}, ...]

  """
  @spec list :: [Participant.t()]
  def list do
    Participant
    |> order_by(asc: :competition_id, asc: :number)
    |> Repo.all()
    |> Repo.preload([:user, :competition, :category])
  end

  @doc """
  Returns the list of participants filtered by competition ID and (optionally) category ID.

  ## Examples

      iex> list("123")
      [%Participant{}, ...]

      iex> list("123", "123")
      [%Participant{}, ...]

  """
  @spec list(String.t(), String.t() | nil) :: [Participant.t()]
  def list(competition_id, category_id \\ nil) do
    conditions =
      if is_nil(category_id) do
        dynamic([p], p.competition_id == ^competition_id)
      else
        dynamic([p], p.competition_id == ^competition_id and p.category_id == ^category_id)
      end

    query =
      from(
        p in Participant,
        where: ^conditions,
        inner_join: u in assoc(p, :user),
        left_join: o in assoc(u, :organization),
        left_join: c in assoc(p, :category),
        left_join: s in assoc(u, :slides),
        on: s.competition_id == ^competition_id,
        group_by: [p.user_id],
        order_by: [asc: :number],
        preload: [category: c, user: {u, [organization: o]}],
        select: %{p | slides_count: count(s.id)}
      )

    Repo.all(query)
  end

  @doc """
  Returns the list of participants filtered by competition ID available for team creation.

  ## Examples

      iex> list_for_teams("123")
      [%Participant{}, ...]
  """
  @spec list_for_teams(String.t()) :: [Participant.t()]
  def list_for_teams(competition_id) do
    teams_query =
      from(
        tm in TeamMember,
        join: t in assoc(tm, :team),
        where: t.competition_id == ^competition_id
      )

    query =
      from(
        p in Participant,
        where: [competition_id: ^competition_id],
        join: u in assoc(p, :user),
        left_join: tm in subquery(teams_query),
        on: tm.user_id == p.user_id,
        where: is_nil(tm.user_id),
        left_join: o in assoc(u, :organization),
        group_by: [p.user_id],
        order_by: [asc: o.name, asc: :number],
        preload: [:category, user: [:organization]]
      )

    Repo.all(query)
  end

  @doc """
  Returns the list of participants filtered by competition ID and name.

  ## Examples

      iex> filter_by_name("123", "foo")
      [%Participant{}, ...]

  """
  @spec filter_by_name(String.t(), String.t()) :: [Participant.t()]
  def filter_by_name(competition_id, name) do
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
        left_join: c in assoc(p, :category),
        left_join: s in assoc(u, :slides),
        on: s.competition_id == ^competition_id,
        group_by: [p.user_id],
        order_by: [asc: :number],
        preload: [category: c, user: {u, [organization: o]}],
        select: %{p | slides_count: count(s.id)}
      )

    Repo.all(query)
  end

  @doc """
  Returns the list of participants filtered by competition ID with their slides.

  ## Examples

      iex> list("123")
      [%Participant{}, ...]

  """
  @spec list_with_slides(String.t()) :: [Participant.t()]
  def list_with_slides(competition_id) do
    slides_query =
      from(s in Slide,
        where: s.status in [:submitted_jury, :submitted_fixed],
        order_by: [asc: :file_name]
      )

    query =
      from(
        p in Participant,
        where: [competition_id: ^competition_id],
        inner_join: u in assoc(p, :user),
        left_join: o in assoc(u, :organization),
        left_join: c in assoc(p, :category),
        order_by: [asc: :number],
        preload: [category: c, user: {u, [organization: o, slides: ^{slides_query, [:subject]}]}]
      )

    Repo.all(query)
  end

  @spec get_next_participant_number(String.t()) :: integer()
  def get_next_participant_number(competition_id) do
    query =
      from(Participant,
        where: [competition_id: ^competition_id],
        order_by: [desc: :number],
        limit: 1,
        select: [:number]
      )

    case Repo.one(query) do
      %SM.Participants.Participant{number: number} -> number + 1
      nil -> 1
    end
  end

  @doc """
  Gets a single Participant.

  ## Examples

  iex> get(123)
  {:ok, %Participant{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t(), String.t()) :: {:error, :not_found} | {:ok, Participant.t()}
  def get(user_id, competition_id) do
    case Repo.get_by(Participant, user_id: user_id, competition_id: competition_id) do
      nil -> {:error, :not_found}
      result -> {:ok, Repo.preload(result, [:competition, :category, user: [:organization]])}
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
    |> case do
      {:ok, participant} ->
        {:ok, Repo.preload(participant, [:user, :competition, :category])}

      {:error,
       %Ecto.Changeset{
         errors: [
           number: {"has already been taken", [constraint: :unique, constraint_name: _name]}
         ],
         valid?: false
       }} ->
        new_number = Map.get(attrs, "number", 0) + 1
        attrs = Map.put(attrs, "number", new_number)
        create(attrs)
    end
    |> notify_subscribers([:participant, :created], id_key: :user_id)
  end

  @doc """
  Import a participant.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Participant{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Participant.t()}
  def import(attrs \\ %{}) do
    %Participant{}
    |> Participant.import_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:participant, :updated], id_key: :user_id)
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
    |> notify_subscribers([:participant, :updated], id_key: :user_id)
  end

  @doc """
  Deletes a Participant.

  ## Examples

      iex> delete(participant)
      {:ok, %Participant{}}

      iex> delete(participant)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Participant.t()) :: {:ok, Participant.t()} | {:error, any()}
  def delete(participant) do
    participant
    |> Repo.delete()
    |> notify_subscribers([:participant, :deleted], id_key: :user_id)
  end

  @doc """
  Deletes a Participant by User ID and Competition ID.

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
    |> notify_subscribers([:participant, :deleted], id_key: :user_id)
  end

  @doc """
  Deletes all Participants.

  ## Examples

  iex> delete_all()
  {:ok, 10}

  """
  @spec delete_all :: {:ok, integer()}
  def delete_all do
    {deleted, nil} = Repo.delete_all(Participant)

    notify_subscribers({:ok, deleted}, [:participant, :deleted], id_key: :user_id)
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
