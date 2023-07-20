defmodule SM.Slides do
  @moduledoc """
  The Slides context.
  """
  use SM, :context

  alias Ecto.Multi
  alias SM.Competitions
  alias SM.ImageProcessing
  alias SM.Jurors.Juror
  alias SM.Participants.Participant
  alias SM.Slides.Slide
  alias SM.Slides.SlideEvaluation
  alias SM.Slides.SlideFlag
  alias SM.Subjects.Subject

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
  Returns the list of slide flag types.

  ## Examples

  iex> list_slide_flag_types()
  [
  wrong_subject: "wrong subject",
  unrecognizable: "unrecognizable",
  distinction: "distinction",
  note: "note"
  ]

  """
  @spec list_slide_flag_types :: [
          {:wrong_subject
           | :unrecognizable
           | :distinction
           | :note, String.t()}
        ]
  def list_slide_flag_types do
    SlideFlag.get_types()
  end

  @spec direct_file_upload? :: boolean()
  def direct_file_upload? do
    :safarimanager
    |> Application.fetch_env!(Slide)
    |> Keyword.fetch!(:direct_file_upload)
  end

  @spec get_uploads_path :: String.t()
  def get_uploads_path do
    :safarimanager
    |> Application.fetch_env!(Slide)
    |> Keyword.fetch!(:uploads_base_path)
  end

  @spec get_uploads_path(String.t(), String.t()) :: String.t()
  def get_uploads_path(competition_id, user_id) do
    Path.join([get_uploads_path(), competition_id, user_id])
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

    ImageProcessing.save_thumbnail(orig_path, width, height, Path.join(thumbs_path, file_name))
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

  @spec list_for_results(String.t(), String.t()) :: [Slide.t()]
  def list_for_results(user_id, competition_id) do
    Slide
    |> where(user_id: ^user_id)
    |> where(competition_id: ^competition_id)
    |> where([sl], sl.status in [:submitted_jury, :submitted_fixed])
    |> order_by(desc: :status, asc: :file_name)
    |> Repo.all()
    |> Repo.preload([:subject, :evaluations])
  end

  @spec list_for_printout(String.t(), String.t()) :: [Slide.t()]
  def list_for_printout(user_id, competition_id) do
    Slide
    |> where(user_id: ^user_id)
    |> where(competition_id: ^competition_id)
    |> where([sl], sl.status in [:submitted_jury, :submitted_fixed])
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
  @spec list_for_jury(String.t()) :: [Slide.t()]
  def list_for_jury(competition_id) do
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

  @spec list_for_validation(String.t()) :: [Slide.t()]
  def list_for_validation(competition_id) do
    query =
      from(sl in Slide,
        join: su in assoc(sl, :subject),
        where: [competition_id: ^competition_id],
        where: sl.status in [:submitted_fixed, :submitted_jury],
        group_by: [sl.id, sl.subject_id, su.numeric_id],
        order_by: [desc: sl.status, asc: su.numeric_id, asc: sl.id],
        preload: [:subject, :evaluations, :slide_flags],
        select: sl
      )

    Repo.all(query)
  end

  @spec list_flagged(String.t()) :: [{Slide.t(), Participant.t()}]
  def list_flagged(competition_id) do
    query =
      from(sl in Slide,
        join: su in assoc(sl, :subject),
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        join: fl in assoc(sl, :slide_flags),
        where: [competition_id: ^competition_id],
        where: sl.status in [:submitted_fixed, :submitted_jury],
        group_by: [sl.id, sl.subject_id, su.numeric_id],
        order_by: [desc: sl.status, asc: su.numeric_id, asc: sl.id],
        preload: [:evaluations, :slide_flags, subject: su],
        select: {p.number, sl}
      )

    Repo.all(query)
  end

  @spec list_duplicate_subjects(String.t()) :: [{Participant.t(), Subject.t(), non_neg_integer()}]
  def list_duplicate_subjects(competition_id) do
    subquery =
      from(sl in Slide,
        join: su in assoc(sl, :subject),
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        where: [competition_id: ^competition_id],
        where: sl.status in [:submitted_fixed, :submitted_jury],
        group_by: [sl.user_id, sl.subject_id],
        having: count(sl.id) > 1
      )

    query =
      from(sl in Slide,
        join: dup in subquery(subquery),
        on:
          dup.competition_id == sl.competition_id and dup.user_id == sl.user_id and
            dup.subject_id == sl.subject_id,
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        order_by: [asc: sl.id],
        preload: [:subject],
        select: {p.number, sl}
      )

    Repo.all(query)
  end

  @spec list_over_submitted_threshold(String.t()) :: [{Participant.t(), non_neg_integer()}]
  def list_over_submitted_threshold(competition_id) do
    query =
      from(sl in Slide,
        join: c in assoc(sl, :competition),
        join: cs in assoc(c, :settings),
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        where: [competition_id: ^competition_id],
        where: sl.status in [:submitted_fixed, :submitted_jury],
        group_by: [sl.user_id],
        order_by: [desc: count(sl.subject_id)],
        select: {p.number, count(sl.id)},
        having: count(sl.id) > cs.max_submitted_slides
      )

    Repo.all(query)
  end

  @spec list_over_static_jury_threshold(String.t()) :: [{Participant.t(), non_neg_integer()}]
  def list_over_static_jury_threshold(competition_id) do
    query =
      from(sl in Slide,
        join: c in assoc(sl, :competition),
        join: cs in assoc(c, :settings),
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        where: [competition_id: ^competition_id],
        where: [status: :submitted_jury],
        group_by: [sl.user_id],
        order_by: [desc: count(sl.subject_id)],
        select: {p.number, count(sl.id)},
        having: count(sl.id) > cs.max_jury_slides
      )

    Repo.all(query)
  end

  @doc """
  SELECT s.ID_concorrente AS Conc, Count(s.id) AS [Num Slide]
    FROM slide AS s
    WHERE (((s.pres)=True))
    GROUP BY s.ID_concorrente
    HAVING (((Count(s.id))>Round(((SELECT Count(id) FROM slide WHERE ID_concorrente = s.ID_concorrente)*((SELECT pspeciep FROM gara)/100)),0)));
  """
  @spec list_over_proportional_jury_threshold(String.t()) :: [
          {Participant.t(), non_neg_integer()}
        ]
  def list_over_proportional_jury_threshold(competition_id) do
    query =
      from(sl in Slide,
        join: c in assoc(sl, :competition),
        join: cs in assoc(c, :settings),
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        where: [competition_id: ^competition_id],
        where: [status: :submitted_jury],
        group_by: [sl.user_id],
        order_by: [desc: count(sl.subject_id)],
        select: {p.number, count(sl.id)},
        having:
          count(sl.id) >
            fragment(
              "SELECT count(s.id) from slides s where s.competition_id = ? and s.user_id = ? and s.status is not null",
              ^competition_id,
              sl.user_id
            ) * cs.submission_ratio + 1
      )

    Repo.all(query)
  end

  @spec list_stats_by_participant(String.t()) :: [{Participant.t(), map()}]
  def list_stats_by_participant(competition_id) do
    query =
      from(sl in Slide,
        join: p in Participant,
        on: p.user_id == sl.user_id and p.competition_id == ^competition_id,
        where: [competition_id: ^competition_id],
        where: sl.status in [:submitted_fixed, :submitted_jury],
        group_by: [:user_id, :status],
        order_by: [asc: p.number],
        select: {p.number, %{sl.status => count(sl.status)}}
      )

    Repo.all(query)
  end

  @doc """
  Returns a count of slides grouped by subject for a competition
  """
  @spec count_by_subject(String.t()) :: %{String.t() => any()}
  def count_by_subject(competition_id) do
    query =
      from(sl in Slide,
        where: [competition_id: ^competition_id],
        join: su in assoc(sl, :subject),
        group_by: [:subject_id],
        order_by: [asc: :subject_id],
        select: %{subject_id: su.id, count: count(su.id)}
      )

    Repo.all(query)
  end

  @doc """
  Returns a count of all participants that submitted slides
  """
  @spec count_submitting_participants(String.t()) :: Decimal.t()
  def count_submitting_participants(competition_id) do
    query =
      from(sl in Slide,
        where: [competition_id: ^competition_id],
        where: not is_nil(sl.status),
        # Workaround added due to ecto_sqlite3 v0.10.0 not supporting
        # DISTINCT inside the count expression.
        # Was failing with error "Distinct not supported in expressions in query"
        # Used to be: select: count(sl.user_id, :distinct)
        select: fragment("count(DISTINCT ?)", sl.user_id)
      )

    Repo.one(query)
  end

  @doc """
  Return a count of the Slides by status for a competition
  """
  @spec count_by_status(Ecto.UUID.t()) :: %{
          submitted_jury: non_neg_integer(),
          submitted_fixed: non_neg_integer(),
          total: non_neg_integer()
        }

  def count_by_status(competition_id) do
    query =
      from(sl in Slide,
        where: [competition_id: ^competition_id],
        where: not is_nil(sl.status),
        group_by: [:status],
        select: {sl.status, count()}
      )

    result =
      query
      |> Repo.all()
      |> Enum.into(%{})

    submitted_jury = Map.get(result, :submitted_jury, 0)
    submitted_fixed = Map.get(result, :submitted_fixed, 0)
    total = submitted_jury + submitted_fixed

    %{submitted_jury: submitted_jury, submitted_fixed: submitted_fixed, total: total}
  end

  @spec count_penalties(Ecto.UUID.t()) :: non_neg_integer()
  def count_penalties(competition_id) do
    query =
      from(sl in Slide,
        where: [competition_id: ^competition_id],
        where: [status: :submitted_jury],
        where: [penalty: true],
        select: count()
      )

    Repo.one(query)
  end

  @spec subjects_distribution(String.t()) :: [Subject.t()]
  def subjects_distribution(competition_id) do
    p_count = count_submitting_participants(competition_id)

    query =
      from(sl in Slide,
        where: [competition_id: ^competition_id],
        where: sl.status in [:submitted_jury, :submitted_fixed],
        join: su in assoc(sl, :subject),
        group_by: [:subject_id],
        order_by: [asc: su.numeric_id],
        select: %Subject{
          su
          | distribution: type(count(su.id) / type(^p_count, :float), :decimal),
            count: count(su.id)
        }
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
      result -> {:ok, Repo.preload(result, [:subject, :evaluations, :slide_flags])}
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
  @spec get(String.t(), String.t() | nil, String.t()) ::
          {:error, :not_found} | {:error, {:multiple_results, String.t()}} | {:ok, Slide.t()}
  def get(_competition_id, nil, _file_name), do: {:error, :not_found}

  def get(competition_id, user_id, file_name) do
    file_name_jpg = "#{file_name}.JPG"
    file_name_jpeg = "#{file_name}.JPEG"

    matches = [file_name, file_name_jpg, file_name_jpeg]

    query =
      from(
        s in Slide,
        where: [competition_id: ^competition_id, user_id: ^user_id],
        where: s.file_name in ^matches
      )

    case Repo.one(query) do
      nil ->
        Logger.warning("Falling back to LIKE query to find slide with file name #{file_name}")
        # Fall back to the LIKE query as a last resort
        find(competition_id, user_id, file_name)

      result ->
        {:ok, result}
    end
  rescue
    e in Ecto.MultipleResultsError ->
      Logger.error("Found multiple slides with name '#{file_name}': #{inspect(e.message)}")
      {:error, {:multiple_results, file_name}}
  end

  @spec find(String.t(), String.t() | nil, String.t()) ::
          {:error, :not_found} | {:error, {:multiple_results, String.t()}} | {:ok, Slide.t()}
  def find(competition_id, user_id, file_name) do
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
  rescue
    e in Ecto.MultipleResultsError ->
      Logger.error("Found multiple slides with name '#{file_name}': #{inspect(e)}")
      {:error, {:multiple_results, file_name}}
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
      multi_copy_file(uploads_path, file_name, user_id, competition_id, tmp_path)
    end)
    |> Multi.run(:verify_duplicate, fn _repo, %{} ->
      case get(competition_id, user_id, file_name) do
        {:ok, result} ->
          Logger.info(
            "Slide #{result.id} from User #{user_id} in Competition #{competition_id} already exists."
          )

          {:error, {:duplicate, result}}

        {:error, :not_found} ->
          {:ok, nil}
      end
    end)
    |> Multi.insert(:slide, fn %{copy_file: file_path} ->
      {:ok, width, height, metadata} = ImageProcessing.get_metadata(file_path)

      metadata =
        case Jason.encode(metadata) do
          {:ok, _encoded} ->
            metadata

          {:error, reason} ->
            Logger.error("Unable to JSON-encode #{file_path} metadata: #{inspect(reason)}")
            %{}
        end

      Slide.changeset(
        %Slide{},
        %{
          user_id: user_id,
          competition_id: competition_id,
          file_name: file_name,
          file_size: file_size,
          file_type: file_type,
          width: width,
          height: height,
          metadata: metadata
        }
      )
    end)
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

      {:error, :verify_duplicate, {:duplicate, existing_slide}, _changes_so_far} ->
        {:ok, existing_slide}

      {:error, failed_operation, failed_value, _changes_so_far} ->
        {:error, {failed_operation, failed_value}}
    end
  end

  @doc """
  Import a slide.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Slide{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Slide.t()}
  def import(attrs \\ %{}) do
    metadata =
      attrs
      |> Map.get("metadata")
      |> then(&(&1 || "{}"))
      |> Jason.decode!()

    attrs = Map.put(attrs, "metadata", metadata)

    slide_flags =
      attrs
      |> Map.get("slide_flags", "[]")
      |> Jason.decode!()
      |> Enum.map(fn slide_flag ->
        %{
          slide_id: Map.fetch!(slide_flag, "slide_id"),
          type: slide_flag |> Map.fetch!("type") |> String.to_existing_atom(),
          context: Map.fetch!(slide_flag, "context"),
          comment: Map.fetch!(slide_flag, "comment"),
          resolved: Map.fetch!(slide_flag, "resolved"),
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    evaluations =
      attrs
      |> Map.get("evaluations", "[]")
      |> Jason.decode!()
      |> Enum.map(fn [user_id, evaluation_id] ->
        %{
          slide_id: Map.fetch!(attrs, "id"),
          user_id: user_id,
          evaluation_id: evaluation_id,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    slide_changeset = Slide.import_changeset(%Slide{}, attrs)

    Multi.new()
    |> Multi.insert(:slide, slide_changeset)
    |> Multi.insert_all(:slide_flags, SlideFlag, slide_flags)
    |> Multi.insert_all(:slide_evaluations, SlideEvaluation, evaluations)
    |> Repo.transaction()
    |> case do
      {:ok, %{slide: slide}} ->
        {:ok, slide}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
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
    with false <- has_penalty?(slide_id),
         [juror] <-
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
           ) do
      create_slide_evaluation(%{
        slide_id: slide_id,
        user_id: juror.user_id,
        evaluation_id: evaluation_id
      })
    else
      true -> {:error, :has_penalty}
      [] -> {:error, :already_evaluated}
    end
  end

  @spec assign_random_evaluations(String.t()) :: :ok
  def assign_random_evaluations(competition_id) do
    {:ok, competition} = Competitions.get(competition_id)
    allowed_evaluations = Map.get(competition, :allowed_evaluations)
    num_of_jurors = Enum.count(competition.jurors)
    evaluations_per_juror = competition.settings.evaluations_per_juror

    competition_id
    |> list_for_jury()
    |> Enum.each(
      &assign_random_evaluation(
        &1,
        num_of_jurors,
        evaluations_per_juror,
        allowed_evaluations,
        competition_id
      )
    )
  end

  @spec assign_fixed_evaluations(String.t(), String.t()) :: :ok
  def assign_fixed_evaluations(competition_id, evaluation_id) do
    {:ok, competition} = Competitions.get(competition_id)
    num_of_jurors = Enum.count(competition.jurors)
    evaluations_per_juror = competition.settings.evaluations_per_juror

    competition_id
    |> list_for_jury()
    |> Enum.each(
      &assign_evaluation(
        &1,
        num_of_jurors,
        evaluations_per_juror,
        evaluation_id,
        competition_id
      )
    )
  end

  @spec create_slide_evaluation(%{(String.t() | atom()) => any()}) ::
          {:error, any()} | {:ok, SlideEvaluation.t()}
  def create_slide_evaluation(attrs \\ %{}) do
    %SlideEvaluation{}
    |> SlideEvaluation.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, slide_evaluation} ->
        notify_subscribers(
          {:ok, Repo.preload(slide_evaluation, [:evaluation, [slide: :evaluations]])},
          [
            :slide,
            :updated
          ]
        )

      {:error, _reason} = error ->
        error
    end
  end

  @spec has_penalty?(String.t()) :: boolean()
  def has_penalty?(slide_id) do
    Repo.one(from(s in Slide, where: [id: ^slide_id], select: s.penalty))
  end

  @spec clear_evaluations(String.t()) :: {:ok, integer()} | {:error, any()}
  def clear_evaluations(slide_id) do
    {deleted, nil} = Repo.delete_all(from(SlideEvaluation, where: [slide_id: ^slide_id]))
    notify_subscribers({:ok, deleted}, [:slide, :updated])
  end

  @spec clear_competition_evaluations(String.t()) :: {:ok, integer()} | {:error, any()}
  def clear_competition_evaluations(competition_id) do
    all_slide_ids =
      competition_id
      |> list_for_jury()
      |> Enum.map(& &1.id)

    query = from(se in SlideEvaluation, where: se.slide_id in ^all_slide_ids)

    {deleted, nil} = Repo.delete_all(query)
    notify_subscribers({:ok, deleted}, [:slide, :updated])
  end

  @spec apply_penalty(String.t()) :: {:ok, Slide.t()} | {:error, any()}
  def apply_penalty(slide_id) do
    Multi.new()
    |> Multi.delete_all(:delete_evaluations, from(SlideEvaluation, where: [slide_id: ^slide_id]))
    |> Multi.update_all(:apply_penalty, from(Slide, where: [id: ^slide_id]), set: [penalty: true])
    |> Repo.transaction()
    |> case do
      {:ok, _result} ->
        {:ok, slide} = get(slide_id)
        notify_subscribers({:ok, slide}, [:slide, :updated])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        {:error, {failed_operation, failed_value}}
    end
  end

  @spec clear_penalty(String.t()) :: {:ok, Slide.t()} | {:error, any()}
  def clear_penalty(slide_id) do
    Multi.new()
    |> Multi.update_all(:clear_penalty, from(Slide, where: [id: ^slide_id]),
      set: [penalty: false]
    )
    |> Repo.transaction()
    |> case do
      {:ok, _result} ->
        {:ok, slide} = get(slide_id)
        notify_subscribers({:ok, slide}, [:slide, :updated])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        {:error, {failed_operation, failed_value}}
    end
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
        Logger.info("Deleted slide #{slide.id} from user #{slide.user_id}")
        notify_subscribers({:ok, slide}, [:slide, :deleted])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error(
          "Failed to delete slide #{slide.id}. #{failed_operation}: #{inspect(failed_value)}"
        )

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
      {:ok, Repo.all(from(s in Slide, where: s.id in ^ids))}
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
          Logger.info("Deleted #{deleted} slide(s)")
          notify_subscribers({:ok, deleted}, [:slide, :deleted])
        else
          Logger.warning("Not all slides could be deleted")
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

  @spec delete_files(String.t()) :: :ok | {:error, any()}
  def delete_files(competition_id) do
    uploads_path = Path.join(get_uploads_path(), competition_id)

    case File.rm_rf(uploads_path) do
      {:ok, _deleted} -> :ok
      {:error, reason, file} -> {:error, {reason, file}}
    end
  end

  @spec delete_files(String.t(), String.t(), String.t()) :: :ok
  def delete_files(competition_id, user_id, file_name) do
    uploads_path = get_uploads_path(competition_id, user_id)
    thumbnails_path = Path.join(uploads_path, "thumbnails")

    _result =
      [uploads_path, file_name]
      |> Path.join()
      |> File.rm()

    [_head | _tail] =
      for size_type <- [:small, :medium, :large] do
        _result =
          [thumbnails_path, Atom.to_string(size_type), file_name]
          |> Path.join()
          |> File.rm()
      end

    # Remove the entire participant directory if empty
    :ok =
      if Path.wildcard(Path.join(uploads_path, "/*.*")) == [] do
        _result = File.rm_rf(uploads_path)
        :ok
      else
        :ok
      end
  end

  # Slide Flags

  @spec list_slide_flags(String.t()) :: %{atom() => SlideFlag.t()}
  def list_slide_flags(slide_id) do
    query =
      from(sf in SlideFlag,
        where: [slide_id: ^slide_id],
        order_by: [asc: :inserted_at]
      )

    Repo.all(query)
    |> Enum.map(fn sf ->
      {sf.type, sf}
    end)
    |> Enum.into(%{})
  end

  @spec get_slide_flag(String.t()) :: {:ok, SlideFlag.t()} | {:error, :not_found}
  def get_slide_flag(slide_flag_id) do
    SlideFlag
    |> Repo.get(slide_flag_id)
    |> case do
      nil -> {:error, :not_found}
      slide_flag -> {:ok, slide_flag}
    end
  end

  @spec add_slide_flag(map()) :: {:ok, SlideFlag.t()} | {:error, any()}
  def add_slide_flag(params) do
    %SlideFlag{}
    |> SlideFlag.changeset(params)
    |> Repo.insert()
    |> notify_subscribers([:slide_flag, :created])
  end

  @spec update_slide_flag(SlideFlag.t(), map()) :: {:ok, SlideFlag.t()} | {:error, any()}
  def update_slide_flag(slide_flag, params) do
    slide_flag
    |> SlideFlag.changeset(params)
    |> Repo.update()
    |> notify_subscribers([:slide_flag, :updated])
  end

  @spec remove_slide_flag(SlideFlag.t()) :: {:ok, SlideFlag.t()} | {:error, any()}
  def remove_slide_flag(slide_flag) do
    slide_flag
    |> Repo.delete()
    |> notify_subscribers([:slide_flag, :deleted])
  end

  @spec clear_slide_flags(String.t()) :: {:ok, non_neg_integer()} | {:error, any()}
  def clear_slide_flags(slide_id) do
    {deleted, nil} = Repo.delete_all(from(SlideFlag, where: [slide_id: ^slide_id]))

    notify_subscribers({:ok, deleted}, [:slide_flag, :deleted])
  end

  @spec apply_correct_subject(String.t(), String.t()) :: {:error, any} | {:ok, Slide.t()}
  def apply_correct_subject(slide_id, new_subject_id) do
    Multi.new()
    |> Multi.one(:slide, from(s in Slide, where: [id: ^slide_id]))
    |> Multi.update(:update_subject, fn %{slide: slide} ->
      Slide.changeset(slide, %{"subject_id" => new_subject_id})
    end)
    |> Multi.one(
      :wrong_subject_flag,
      from(sf in SlideFlag, where: [slide_id: ^slide_id, type: :wrong_subject])
    )
    |> Multi.delete(:remove_flag, fn %{wrong_subject_flag: flag} ->
      flag
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _context} ->
        notify_subscribers(get(slide_id), [:slide, :updated])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error(
          "Error applying correct subject. #{failed_operation}: #{inspect(failed_value)}"
        )

        notify_subscribers(:error, [:slide, :updated])
    end
  end

  @spec slide_flags_by_types(Slide.t()) :: %{atom() => SlideFlag.t()}
  def slide_flags_by_types(slide) do
    flags =
      slide.slide_flags
      |> Enum.map(fn sf ->
        {sf.type, sf}
      end)

    list_slide_flag_types()
    |> Enum.map(&{elem(&1, 0), nil})
    |> Keyword.merge(flags)
    |> Enum.into(%{})
  end

  # Internal

  defp multi_copy_file(uploads_path, file_name, user_id, competition_id, tmp_path) do
    :ok = File.mkdir_p!(uploads_path)
    file_path = Path.join(uploads_path, file_name)

    if File.exists?(file_path) do
      Logger.info(
        "File #{file_name} from User #{user_id} in Competition #{competition_id} already exists."
      )

      {:ok, file_path}
    else
      with :ok <- File.cp(tmp_path, file_path),
           do: {:ok, file_path}
    end
  end

  defp assign_random_evaluation(
         slide,
         num_of_jurors,
         evaluations_per_juror,
         allowed_evaluations,
         competition_id
       ) do
    Enum.each(0..num_of_jurors, fn _juror ->
      Enum.each(0..evaluations_per_juror, fn _evaluation ->
        random_evaluation = Enum.random(allowed_evaluations)
        evaluate(competition_id, slide.id, random_evaluation.id)
      end)
    end)
  end

  defp assign_evaluation(
         slide,
         num_of_jurors,
         evaluations_per_juror,
         evaluation_id,
         competition_id
       ) do
    Enum.each(0..num_of_jurors, fn _juror ->
      Enum.each(0..evaluations_per_juror, fn _evaluation ->
        evaluate(competition_id, slide.id, evaluation_id)
      end)
    end)
  end
end
