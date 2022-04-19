defmodule SM.Slides do
  @moduledoc """
  The Slides context.
  """
  use SM, :context

  alias Ecto.Multi
  alias SM.ImageProcessing
  alias SM.Jurors.Juror
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
    path =
      :safarimanager
      |> Application.fetch_env!(Slide)
      |> Keyword.fetch!(:uploads_base_path)

    Path.join([path, competition_id, user_id])
  end

  @spec get_thumbnails_path(String.t(), String.t(), :small | :medium | :large) :: String.t()
  def get_thumbnails_path(competition_id, user_id, size_type)
      when size_type in [:small, :medium, :large] do
    path = get_uploads_path(competition_id, user_id)

    Path.join([path, "thumbnails", Atom.to_string(size_type)])
  end

  @spec get_thumbnail_size(:small | :medium | :large) :: {non_neg_integer(), non_neg_integer()}
  def get_thumbnail_size(size_type) do
    :safarimanager
    |> Application.fetch_env!(Slide)
    |> Keyword.fetch!(:thumbnails)
    |> Keyword.fetch!(size_type)
  end

  @spec generate_thumbnail(String.t(), String.t(), String.t(), :small | :medium | :large) ::
          :ok | {:error, any()}
  def generate_thumbnail(competition_id, user_id, file_name, size_type) do
    orig_path =
      competition_id
      |> get_uploads_path(user_id)
      |> Path.join(file_name)

    # %{height: height, width: width, format: format} = ImageProcessing.get_info(orig_path)
    # IO.inspect("running task for image #{file_name}:", label: __MODULE__)
    # IO.inspect(%{height: height, width: width, format: format}, label: __MODULE__)

    thumbs_path = get_thumbnails_path(competition_id, user_id, size_type)
    File.mkdir_p!(thumbs_path)

    {width, height} = get_thumbnail_size(size_type)

    {:ok, _path} =
      ImageProcessing.save_thumbnail(orig_path, width, height, Path.join(thumbs_path, file_name))

    :ok
  rescue
    error ->
      {:error, error}
  end

  @spec jury_bool_to_status(boolean()) :: :submitted_fixed | :submitted_jury
  def jury_bool_to_status(jury?) when is_boolean(jury?) do
    if jury?, do: :submitted_jury, else: :submitted_fixed
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
    |> order_by(asc: :file_name)
    |> Repo.all()
    |> Repo.preload([:subject, :evaluations])
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
      result -> {:ok, Repo.preload(result, [:subject, :evaluations])}
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
    file_name_match = "#{file_name}%"

    query =
      from(
        s in Slide,
        where: [competition_id: ^competition_id, user_id: ^user_id],
        where: fragment(@like_fragment, s.file_name, ^file_name_match)
      )

    case Repo.one(query) do
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

  @spec create_and_store_slide_file(
          String.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          String.t(),
          String.t()
        ) :: {:error, any()} | {:ok, Slide.t()}
  def create_and_store_slide_file(
        competition_id,
        user_id,
        file_name,
        file_size,
        file_type,
        tmp_path
      ) do
    uploads_path = get_uploads_path(competition_id, user_id)

    Multi.new()
    |> Multi.run(:copy_file, fn _repo, %{} ->
      :ok = File.mkdir_p!(uploads_path)
      file_path = Path.join(uploads_path, file_name)

      with :ok <- File.cp(tmp_path, file_path),
           do: {:ok, file_path}
    end)
    |> Multi.insert(
      :slide,
      fn %{copy_file: file_path} ->
        {:ok, metadata} = ImageProcessing.get_metadata(file_path)
        gps = Map.get(metadata, :gps)
        metadata = Map.put(metadata, :gps, (gps && Map.from_struct(gps)) || %{})

        Slide.changeset(%Slide{}, %{
          user_id: user_id,
          competition_id: competition_id,
          file_name: file_name,
          file_size: file_size,
          file_type: file_type,
          width: metadata.exif.exif_image_width,
          height: metadata.exif.exif_image_height,
          metadata: metadata
        })
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{slide: slide}} ->
        notify_subscribers({:ok, slide}, [:slide, :created])

      {:error, :slide, failed_value, _changes_so_far} ->
        :ok =
          [uploads_path, file_name]
          |> Path.join()
          |> File.rm()

        {:error, {:slide, failed_value}}

      {:error, failed_operation, failed_value, _changes_so_far} ->
        {:error, {failed_operation, failed_value}}
    end
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
  Evaluate a slide using a free Juror.

  ## Examples

      iex> evaluate(123, 456, 789)
      {:ok, %SlideEvaluation{}}

      iex> evaluate(321, 654, 987)
      {:error, %Ecto.Changeset{}}

  """
  @spec evaluate(String.t(), String.t(), String.t()) ::
          {:ok, SlideEvaluation.t()} | {:error, any()}
  def evaluate(competition_id, slide_id, evaluation_id) do
    free_jurors =
      Repo.all(
        from(
          j in Juror,
          left_join: se in SlideEvaluation,
          on: se.user_id == j.user_id and se.slide_id == ^slide_id,
          where: is_nil(se.user_id),
          where: [competition_id: ^competition_id],
          order_by: [asc: :inserted_at],
          limit: 1
        )
      )

    case free_jurors do
      [juror] ->
        create_slide_evaluation(%{
          slide_id: slide_id,
          user_id: juror.user_id,
          evaluation_id: evaluation_id
        })

      [] ->
        {:error, :already_evaluated}
    end
  end

  @spec create_slide_evaluation(%{(String.t() | atom()) => any()}) ::
          {:error, any()} | {:ok, SlideEvaluation.t()}
  def create_slide_evaluation(attrs \\ %{}) do
    %SlideEvaluation{}
    |> SlideEvaluation.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, slide_evaluation} ->
        notify_subscribers({:ok, Repo.preload(slide_evaluation, [:evaluation])}, [
          :slide,
          :updated
        ])

      {:error, _reason} = error ->
        error
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
    Multi.new()
    |> Multi.delete(:delete, slide)
    |> Multi.run(:delete_files, fn _repo, %{delete: slide} ->
      :ok = delete_files(slide.competition_id, slide.user_id, slide.file_name)

      {:ok, :deleted}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delete: slide}} ->
        notify_subscribers({:ok, slide}, [:slide, :deleted])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        {:error, {failed_operation, failed_value}}
    end
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
    Multi.new()
    |> Multi.run(:slides, fn _repo, %{} ->
      {:ok, Repo.all(from s in Slide, where: s.id in ^ids)}
    end)
    |> Multi.delete_all(:delete_many, from(entity in Slide, where: entity.id in ^ids))
    |> Multi.run(:delete_files, fn _repo, %{slides: slides} ->
      Enum.each(slides, &delete_files(&1.competition_id, &1.user_id, &1.file_name))

      {:ok, :deleted}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delete_many: deleted}} ->
        if deleted == Enum.count(ids) do
          notify_subscribers({:ok, deleted}, [:slide, :deleted])
        else
          notify_subscribers(:error, [:slide, :deleted])
        end

      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error(
          "Failed to delete multiple slides. #{failed_operation}: #{inspect(failed_value)}"
        )

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

  # Internal

  defp delete_files(competition_id, user_id, file_name) do
    uploads_path = get_uploads_path(competition_id, user_id)
    thumbnails_path = Path.join(uploads_path, "thumbnails")

    :ok =
      [uploads_path, file_name]
      |> Path.join()
      |> File.rm()

    for size_type <- [:small, :medium, :large] do
      :ok =
        [thumbnails_path, Atom.to_string(size_type), file_name]
        |> Path.join()
        |> File.rm()
    end

    # Remove the entire participant directory if empty
    :ok =
      if Path.wildcard(Path.join(uploads_path, "/*.*")) == [] do
        {:ok, _result} = File.rm_rf(uploads_path)
        :ok
      else
        :ok
      end
  end
end
