defmodule SM.Organizations do
  @moduledoc """
  The Organizations context.
  """
  use SM, :context

  alias SM.Organizations.Organization

  @topic inspect(__MODULE__)

  def subscribe do
    Phoenix.PubSub.subscribe(SM.PubSub, @topic)
  end

  def subscribe(organization_id) do
    Phoenix.PubSub.subscribe(SM.PubSub, @topic <> "#{organization_id}")
  end

  @doc """
  Returns the list of organizations.

  ## Examples

      iex> list()
      [%Organization{}, ...]

  """
  def list do
    Organization
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single organization.

  Raises `Ecto.NoResultsError` if the Organization does not exist.

  ## Examples

      iex> get(123)
      {:ok, %Organization{}}

      iex> get(456)
      {:error, :not_found}

  """
  def get(id) do
    case Repo.get(Organization, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a organization.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Organization{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create(attrs \\ %{}) do
    %Organization{}
    |> Organization.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:organization, :created])
  end

  @doc """
  Updates a organization.

  ## Examples

      iex> update(organization, %{field: new_value})
      {:ok, %Organization{}}

      iex> update(organization, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update(%Organization{} = organization, attrs) do
    organization
    |> Organization.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:organization, :updated])
  end

  @doc """
  Deletes a Organization.

  ## Examples

      iex> delete(organization)
      {:ok, %Organization{}}

      iex> delete(organization)
      {:error, %Ecto.Changeset{}}

  """
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
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from org in Organization, where: org.id in ^ids)

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
  def change(%Organization{} = organization, params \\ %{}) do
    Organization.changeset(organization, params)
  end

  # Internal

  defp notify_subscribers({:ok, result}, event) when is_struct(result) do
    Phoenix.PubSub.broadcast(SM.PubSub, @topic, {__MODULE__, event, result})

    Phoenix.PubSub.broadcast(
      SM.PubSub,
      @topic <> "#{result.id}",
      {__MODULE__, event, result}
    )

    {:ok, result}
  end

  defp notify_subscribers({:ok, result}, event) do
    Phoenix.PubSub.broadcast(SM.PubSub, @topic, {__MODULE__, event, result})

    {:ok, result}
  end

  defp notify_subscribers({:error, reason}, _), do: {:error, reason}
  defp notify_subscribers(:error, _), do: :error
end
