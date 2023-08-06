defmodule SM.Teams do
  @moduledoc """
  The Teams context.
  """
  use SM, :context

  alias SM.Organizations
  alias SM.Teams.Team
  alias SM.Teams.TeamMember

  @doc """
  Returns the list of teams.

  ## Examples

      iex> list()
      [%Team{}, ...]

  """
  @spec list :: [Team.t()]
  def list do
    Team
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> Repo.preload([:users, :competition])
  end

  @doc """
  Returns the list of teams filtered by name.

  ## Examples

      iex> list_by_name()
      [%Team{}, ...]

  """
  @spec list_by_name(String.t()) :: [Team.t()]
  def list_by_name(name) do
    pattern = "%#{name}%"

    query =
      from(
        t in Team,
        order_by: [desc: :inserted_at],
        where: fragment(@like_fragment, t.name, ^pattern)
      )

    query
    |> Repo.all()
    |> Repo.preload([:users])
  end

  @doc """
  Returns the list of member user IDs by competition ID.

  ## Examples

      iex> list_member_users("123)
      [345, 678, ...]

  """
  @spec list_member_users(String.t()) :: [String.t()]
  def list_member_users(competition_id) do
    query =
      from(tm in TeamMember,
        where: [competition_id: ^competition_id],
        select: tm.user_id
      )

    Repo.all(query)
  end

  @doc """
  Gets a single Team.

  ## Examples

  iex> get(123)
  {:ok, %Team{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Team.t()}
  def get(id) do
    case Repo.get(Team, id) do
      nil ->
        {:error, :not_found}

      result ->
        {:ok, Repo.preload(result, [:users, :members, :competition])}
    end
  end

  @doc """
  Creates a team.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Team{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(map()) :: {:error, any()} | {:ok, Team.t()}
  def create(attrs \\ %{}) do
    %Team{}
    |> change(attrs)
    |> Repo.insert()
    |> case do
      {:ok, team} ->
        {:ok, Repo.preload(team, [:users, :competition])}

      {:error, _reason} = error ->
        error
    end
    |> notify_subscribers([:team, :created])
  end

  @doc """
  Import a team.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Team{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Team.t()}
  def import(attrs \\ %{}) do
    %Team{}
    |> Team.import_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:team, :created])
  end

  @doc """
  Updates a team.

  ## Examples

      iex> update(team, %{"field" => "new_value"})
      {:ok, %Team{}}

      iex> update(team, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Team.t(), %{String.t() => any()}) ::
          {:ok, Team.t()} | {:error, any()}
  def update(%Team{} = team, attrs) do
    team
    |> change(attrs)
    |> Repo.update()
    |> case do
      {:ok, team} ->
        {:ok, Repo.preload(team, [:users])}

      {:error, _reason} = error ->
        error
    end
    |> notify_subscribers([:team, :updated])
  end

  @doc """
  Deletes a Team.

  ## Examples

      iex> delete(team)
      {:ok, %Team{}}

      iex> delete(team)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Team.t()) :: {:ok, Team.t()} | {:error, any()}
  def delete(%Team{} = team) do
    team
    |> Repo.delete()
    |> notify_subscribers([:team, :deleted])
  end

  @doc """
  Deletes many Teams by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, ["id1", "id2", "id3"]}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, [String.t()]} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Team, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, ids}, [:team, :deleted])
    else
      notify_subscribers(:error, [:team, :deleted])
    end
  end

  @doc """
  Deletes all Teams.

  ## Examples

  iex > delete_all()
  {:ok, 10}

  """
  @spec delete_all :: {:ok, integer()}
  def delete_all do
    {deleted, nil} = Repo.delete_all(Team)

    notify_subscribers({:ok, deleted}, [:team, :deleted])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking team changes.

  ## Examples

  iex> change(team)
  %Ecto.Changeset{source: %Team{}}

  """
  @spec change(Team.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Team{} = team, params \\ %{}) do
    team
    |> Team.changeset(params)
  end

  @spec synthesize_team_name(Team.t()) :: String.t() | nil
  def synthesize_team_name(%Team{members: [_ | _] = members}) do
    members
    |> Enum.map(& &1.user.last_name)
    |> Enum.join(" - ")
  end

  def synthesize_team_name(_team), do: nil

  @spec synthesize_org_name(Team.t()) :: String.t() | nil
  def synthesize_org_name(%Team{members: [first | _] = members}) do
    first_org_id = first.user.organization_id

    if Enum.all?(members, &(&1.user.organization_id == first_org_id)) do
      {:ok, organization} = Organizations.get(first_org_id)
      organization.name
    else
      nil
    end
  end

  def synthesize_org_name(_team), do: nil
end
