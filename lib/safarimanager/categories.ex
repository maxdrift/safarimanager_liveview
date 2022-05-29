defmodule SM.Categories do
  @moduledoc """
  The Categories context.
  """
  use SM, :context

  alias SM.Categories.Category

  @doc """
  Returns the list of categories.

  ## Examples

  iex> list()
  [%Category{}, ...]

  """
  @spec list :: [Category.t()]
  def list do
    Category
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of categories filtered by name.

  ## Examples

  iex> list_by_name()
  [%Category{}, ...]

  """
  @spec list_by_name(String.t()) :: [Category.t()]
  def list_by_name(name) do
    pattern = "%#{name}%"

    query =
      from(
        o in Category,
        order_by: [desc: :inserted_at],
        where: fragment(@like_fragment, o.name, ^pattern)
      )

    Repo.all(query)
  end

  @doc """
  Gets a single category.

  ## Examples

  iex> get(123)
  {:ok, %Category{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Category.t()}
  def get(id) do
    case Repo.get(Category, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a category.

  ## Examples

  iex> create(%{field: value})
  {:ok, %Category{}}

  iex> create(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec create(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Category.t()}
  def create(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:category, :created])
  end

  @doc """
  Updates a category.

  ## Examples

  iex> update(category, %{"field" => "new_value"})
  {:ok, %Category{}}

  iex> update(category, %{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec update(Category.t(), %{String.t() => any()}) ::
          {:ok, Category.t()} | {:error, any()}
  def update(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:category, :updated])
  end

  @doc """
  Deletes a Category.

  ## Examples

  iex> delete(category)
  {:ok, %Category{}}

  iex> delete(category)
  {:error, %Ecto.Changeset{}}

  """
  @spec delete(Category.t()) :: {:ok, Category.t()} | {:error, any()}
  def delete(%Category{} = category) do
    category
    |> Repo.delete()
    |> notify_subscribers([:category, :deleted])
  end

  @doc """
  Deletes many Categories by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Category, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:category, :deleted])
    else
      notify_subscribers(:error, [:category, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.

  ## Examples

  iex> change(category)
  %Ecto.Changeset{source: %Category{}}

  """
  @spec change(Category.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Category{} = category, params \\ %{}) do
    Category.changeset(category, params)
  end
end
