defmodule SM.Slides do
  @moduledoc """
  The Slides context.
  """
  use SM, :context

  alias SM.Evaluations
  alias SM.Slides.Slide
  alias SM.Slides.SlideEvaluation

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

  @spec get_uploads_path(String.t(), String.t()) :: String.t()
  def get_uploads_path(competition_id, user_id) do
    fun =
      :safarimanager
      |> Application.fetch_env!(Slide)
      |> Keyword.fetch!(:uploads_path)

    fun.(competition_id, user_id)
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
    |> Repo.preload([:subject])
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
    |> Repo.preload([:subject])
  end

  @doc """
  Returns the list of slides grouped by subject, in random order (by slide ID).

  select
      sl.id,
      su.name
      sl.file_name,
  from
      slides sl
      inner join subjects su on su.id = sl.subject_id
  where
      sl.competition_id = '7e1ce81a-fc38-4f9d-a182-6f7bbbcf6504'
      and sl.status = 'submitted_jury'
  group by
      sl.id,
      sl.subject_id,
      su.name,
      u.first_name
  order by
      sl.subject_id;

  ## Examples

      iex> list(competition_id)
      [%Slide{}, ...]

  """
  @spec list(String.t()) :: [Slide.t()]
  def list(competition_id) do
    query =
      from(sl in Slide,
        join: su in assoc(sl, :subject),
        where: [competition_id: ^competition_id, status: :submitted_jury],
        group_by: [sl.id, sl.subject_id, su.numeric_id],
        order_by: [asc: su.numeric_id, asc: sl.id],
        preload: [:subject, :evaluations],
        select: sl
      )

    Repo.all(query)
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
      result -> {:ok, Repo.preload(result, [:evaluations])}
    end
  end

  @doc """
  Gets a single Slide by competition, user and file name.

  ## Examples

  iex> get(123, 123, "foobar")
  {:ok, %Slide{}}

  iex> get(456, 456, "foobar")
  {:error, :not_found}

  """
  @spec get(String.t(), String.t(), String.t()) :: {:error, :not_found} | {:ok, Slide.t()}
  def get(competition_id, user_id, file_name) do
    case Repo.get_by(Slide, competition_id: competition_id, user_id: user_id, file_name: file_name) do
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
  @spec create(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Slide.t()}
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
  @spec update(Slide.t(), %{(String.t() | atom()) => any()}) :: {:ok, Slide.t()} | {:error, any()}
  def update(%Slide{} = slide, attrs) do
    slide
    |> Slide.changeset(attrs)
    |> Repo.update()
    |> notify_subscribers([:slide, :updated])
  end

  @doc """
  Evaluate a slide.

  ## Examples

      iex> evaluate(123, 456)
      {:ok, %Slide{}}

      iex> evaluate(678, 901)
      {:error, %Ecto.Changeset{}}

  """
  @spec evaluate(String.t(), String.t(), String.t(), Keyword.t()) ::
          {:ok, Slide.t()} | {:error, any()}
  def evaluate(slide_id, user_id, evaluation_id, _opts \\ []) do
    # max_evaluations = Keyword.get(opts, :max_evaluations)

    changeset =
      SlideEvaluation.changeset(%SlideEvaluation{}, %{
        slide_id: slide_id,
        user_id: user_id,
        evaluation_id: evaluation_id
      })

    Multi.new()
    # |> Multi.run(:evaluations, fn _repo, %{} ->
    #   evaluations = Evaluations.list(slide_id)

    #   if is_nil(max_evaluations) or Enum.count(evaluations) < max_evaluations do
    #     {:ok, evaluations}
    #   else
    #     {:error, {:max_evaluations, evaluations}}
    #   end
    # end)
    |> Multi.insert(:evaluate, changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{evaluate: slide_evaluation}} ->
        notify_subscribers({:ok, slide_evaluation}, [:slide, :updated])

      {:error, failed_operation, failed_value, _context} ->
        {:error, {failed_operation, failed_value}}
    end
  end

  @spec clear_evaluations(String.t()) :: {:ok, integer()} | {:error, any()}
  def clear_evaluations(slide_id) do
    {deleted, nil} = Repo.delete_all(from(SlideEvaluation, where: [slide_id: ^slide_id]))
    notify_subscribers({:ok, deleted}, [:slide, :updated])
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
