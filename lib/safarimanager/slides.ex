defmodule SM.Slides do
  @moduledoc """
  The Slides context.
  """
  use SM, :context

  alias SM.Slides.Slide

  @doc """
  Returns the list of slide statuses.

  ## Examples

  iex> list_slide_statuses()
  [:discarded, :submitted_jury, :submitted_fixed]

  """
  @spec list_slide_statuses :: [:discarded | :submitted_jury | :submitted_fixed, ...]
  def list_slide_statuses do
    Slide.get_statuses()
  end

  @doc """
  Returns the list of slides.

  ## Examples

      iex> list()
      [%Slide{}, ...]

  """
  @spec list :: [Slide.t()]
  def list do
    Slide
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of slides by User and Competition.

  ## Examples

      iex> list(user_id, competition_id)
      [%Slide{}, ...]

  """
  @spec list(String.t(), String.t()) :: [Slide.t()]
  def list(user_id, competition_id) do
    Slide
    |> where(user_id: ^user_id)
    |> where(competition_id: ^competition_id)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single Slide.

  ## Examples

  iex> get(123)
  {:ok, %Slide{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Slide.t()}
  def get(id) do
    case Repo.get(Slide, id) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Creates a slide.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Slide{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(%{String.t() => any()}) :: {:error, any()} | {:ok, Slide.t()}
  def create(attrs \\ %{}) do
    %Slide{}
    |> Slide.changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:slide, :created])
  end

  @doc """
  Updates a slide.

  ## Examples

      iex> update(slide, %{"field" => "new_value"})
      {:ok, %Slide{}}

      iex> update(slide, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Slide.t(), %{String.t() => any()}) :: {:ok, Slide.t()} | {:error, any()}
  def update(%Slide{} = slide, attrs) do
    slide
    |> Slide.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:slide, :updated])
  end

  @doc """
  Deletes a Slide.

  ## Examples

      iex> delete(slide)
      {:ok, %Slide{}}

      iex> delete(slide)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Slide.t()) :: {:ok, Slide.t()} | {:error, any()}
  def delete(%Slide{} = slide) do
    slide
    |> Repo.delete()
    |> notify_subscribers([:slide, :deleted])
  end

  @doc """
  Deletes many Slides by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Slide, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:slide, :deleted])
    else
      notify_subscribers(:error, [:slide, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking slide changes.

  ## Examples

  iex> change(slide)
  %Ecto.Changeset{source: %Slide{}}

  """
  @spec change(Slide.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change(%Slide{} = slide, params \\ %{}) do
    Slide.changeset(slide, params)
  end
end
