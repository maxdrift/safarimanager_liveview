defmodule SM.Organizations do
  @moduledoc """
  The Organizations context.
  """
  use SM, :context

  alias SM.Accounts.User
  alias SM.Competitions.Competition
  alias SM.Organizations.Organization

  @doc """
  Returns the list of organizations.

  ## Examples

  iex> list()
  [%Organization{}, ...]

  """
  @spec list :: [Organization.t()]
  def list do
    Organization
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of organizations filtered by name.

  ## Examples

  iex> list_by_name()
  [%Organization{}, ...]

  """
  @spec list_by_name(String.t()) :: [Organization.t()]
  def list_by_name(name) do
    pattern = "%#{name}%"

    query =
      from(
        o in Organization,
        order_by: [desc: :inserted_at],
        where: fragment(@like_fragment, o.name, ^pattern)
      )

    Repo.all(query)
  end

  @doc """
  Gets a single organization.

  ## Examples

  iex> get(123)
  {:ok, %Organization{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Organization.t()}
  def get(id) do
    case Repo.get(Organization, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates an organization.

  ## Examples

  iex> create(%{field: value})
  {:ok, %Organization{}}

  iex> create(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec create(map()) :: {:error, any()} | {:ok, Organization.t()}
  def create(attrs \\ %{}) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:organization, :created])
  end

  @doc """
  Import an organization.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Organization{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{String.t() => any()}) :: {:error, any()} | {:ok, Organization.t()}
  def import(attrs \\ %{}) do
    %Organization{}
    |> Organization.import_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:organization, :created])
  end

  @doc """
  Updates an organization.

  ## Examples

  iex> update(organization, %{"field" => "new_value"})
  {:ok, %Organization{}}

  iex> update(organization, %{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec update(Organization.t(), %{String.t() => any()}) ::
          {:ok, Organization.t()} | {:error, any()}
  def update(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:organization, :updated])
  end

  @doc """
  Deletes an organization.

  ## Examples

  iex> delete(organization)
  {:ok, %Organization{}}

  iex> delete(organization)
  {:error, %Ecto.Changeset{}}

  """
  @spec delete(Organization.t()) :: {:ok, Organization.t()} | {:error, any()}
  def delete(%Organization{} = organization) do
    organization
    |> Repo.delete()
    |> notify_subscribers([:organization, :deleted])
  end

  @doc """
  Deletes many Organizations by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Organization, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:organization, :deleted])
    else
      notify_subscribers(:error, [:organization, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking organization changes.

  ## Examples

  iex> change(organization)
  %Ecto.Changeset{source: %Organization{}}

  """
  @spec change(Organization.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Organization{} = organization, params \\ %{}) do
    Organization.changeset(organization, params)
  end

  @spec merge([String.t()], String.t()) :: {:ok, Organization.t()} | {:error, any()}
  def merge(ids, dest_id) when is_list(ids) do
    user_query = from(u in User, where: u.organization_id in ^ids)
    competition_query = from(c in Competition, where: c.organization_id in ^ids)
    organization_query = from(o in Organization, where: o.id in ^ids)

    Multi.new()
    |> Multi.one(:organization, from(Organization, where: [id: ^dest_id]))
    |> Multi.update_all(:update_users, user_query, set: [organization_id: dest_id])
    |> Multi.update_all(:update_competitions, competition_query, set: [organization_id: dest_id])
    |> Multi.delete_all(:delete_organizations, organization_query)
    |> Repo.transaction()
    |> case do
      {:ok, %{organization: organization}} ->
        notify_subscribers({:ok, organization}, [:organization, :deleted])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        notify_subscribers({:error, {failed_operation, failed_value}}, [:organization, :deleted])
    end
  end

  @spec merge(String.t(), String.t()) :: {:ok, Organization.t()} | {:error, any()}
  def merge(id, dest_id) do
    merge([id], dest_id)
  end
end
