defmodule SM.Competitions do
  @moduledoc """
  The Competitions context.
  """
  use SM, :context

  alias Ecto.Multi
  alias SM.Categories.Category
  alias SM.Competitions.Competition
  alias SM.Competitions.CompetitionSettings
  alias SM.Participants.Participant
  alias SM.Slides

  @doc """
  Returns the list of competition types.

  ## Examples

  iex> list_competition_types()
  [
    {:qualification, "qualification"},
    {:national_championship, "national championship"},
    {:international_championship, "international championship"},
    {:local_event, "local event"},
    {:national_event, "national event"},
    {:international_event, "international event"}
  ]
  """
  @spec list_competition_types :: [
          {
            :qualification
            | :national_championship
            | :international_championship
            | :local_event
            | :national_event
            | :international_event,
            String.t()
          }
        ]
  def list_competition_types do
    Competition.get_types()
  end

  @doc """
  Returns the list of competitions.

  ## Examples

      iex> list()
      [%Competition{}, ...]

  """
  @spec list :: [Competition.t()]
  def list do
    Competition
    |> order_by(desc: :inserted_at)
    |> Repo.all()
    |> Repo.preload([:organization, :competitions_evaluations])
  end

  @doc """
  Returns the list of competitions filtered by name.

  ## Examples

      iex> list_by_name()
      [%Competition{}, ...]

  """
  @spec list_by_name(String.t()) :: [Competition.t()]
  def list_by_name(name) do
    pattern = "%#{name}%"

    query =
      from(
        c in Competition,
        order_by: [desc: :inserted_at],
        where: fragment(@like_fragment, c.name, ^pattern)
      )

    query
    |> Repo.all()
    |> Repo.preload([:organization])
  end

  @doc """
  Returns the list of categories in a competitions.

  ## Examples

      iex> list_categories()
      [%Category{}, ...]

  """
  @spec list_categories(String.t()) :: [Category.t()]
  def list_categories(competition_id) do
    query =
      from(
        c in Competition,
        where: [id: ^competition_id],
        join: p in Participant,
        on: p.competition_id == c.id,
        join: cat in assoc(p, :category),
        on: p.category_id == cat.id,
        group_by: p.category_id,
        select: cat
      )

    Repo.all(query)
  end

  @doc """
  Returns the list of camera types in a competitions.

  ## Examples

      iex> list_camera_types()
      [%Category{}, ...]

  """
  @spec list_camera_types(String.t()) :: [Category.t()]
  def list_camera_types(competition_id) do
    query =
      from(
        c in Competition,
        where: [id: ^competition_id],
        join: p in Participant,
        on: p.competition_id == c.id,
        join: cat in assoc(p, :category),
        on: p.category_id == cat.id,
        group_by: cat.camera_type,
        select: cat.camera_type
      )

    Repo.all(query)
  end

  @doc """
  Gets a single Competition.

  ## Examples

  iex> get(123)
  {:ok, %Competition{}}

  iex> get(456)
  {:error, :not_found}

  """
  @spec get(String.t()) :: {:error, :not_found} | {:ok, Competition.t()}
  def get(id) do
    case Repo.get(Competition, id) do
      nil ->
        {:error, :not_found}

      result ->
        {:ok,
         Repo.preload(result, [
           [participants: [:category, [user: :organization]]],
           [jurors: [user: :organization]],
           :teams,
           :competitions_evaluations,
           :allowed_evaluations,
           :organization,
           :settings
         ])}
    end
  end

  @doc """
  Creates a competition.

  ## Examples

      iex> create(%{field: value})
      {:ok, %Competition{}}

      iex> create(%{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create(map()) :: {:error, any()} | {:ok, Competition.t()}
  def create(attrs \\ %{}) do
    %Competition{}
    |> change(attrs)
    |> Repo.insert()
    |> case do
      {:ok, competition} ->
        competition = Repo.preload(competition, :organization)

        notify_subscribers({:ok, competition}, [:competition, :created])

      {:error, changeset} ->
        notify_subscribers({:error, changeset}, [:competition, :created])
    end
  end

  @doc """
  Duplicate a competition.
  """
  @spec duplicate(String.t(), map()) :: {:ok, Competition.t()} | {:error, any()}
  def duplicate(id, config \\ %{}) do
    case get(id) do
      {:ok, existing_competition} ->
        existing_competition = Repo.preload(existing_competition, slides: [:slide_flags, :votes])

        competition_params =
          existing_competition
          |> duplicate_competition_details(config)
          |> maybe_duplicate_participants(existing_competition, config)
          |> maybe_duplicate_teams(existing_competition, config)
          |> maybe_duplicate_jurors(existing_competition, config)
          |> maybe_duplicate_slides(existing_competition, config)

        %Competition{}
        |> Competition.duplication_changeset(competition_params)
        |> Repo.insert()
        |> case do
          {:ok, new_competition} ->
            notify_subscribers({:ok, Repo.preload(new_competition, :organization)}, [:competition, :created])

          {:error, reason} ->
            notify_subscribers({:error, reason}, [:competition, :created])
        end

      {:error, reason} ->
        notify_subscribers({:error, reason}, [:competition, :created])
    end
  end

  defp duplicate_competition_details(competition, config) do
    competition_name =
      if config["new_competition_name"] in [nil, ""], do: competition.name, else: config["new_competition_name"]

    params =
      competition
      |> Map.from_struct()
      |> Map.put(:name, competition_name)
      |> Map.put(:for_teams, config["new_for_teams"])

    competition_settings = Map.from_struct(competition.settings)
    dynamic_coefficients = Enum.map(competition.settings.dynamic_coefficients, &Map.from_struct/1)

    competitions_evaluations =
      competition.competitions_evaluations
      |> Enum.map(&Map.from_struct/1)
      |> Enum.with_index()
      |> Map.new(fn {item, index} -> {index, item} end)

    competition_settings = Map.put(competition_settings, :dynamic_coefficients, dynamic_coefficients)

    params
    |> Map.put(:settings, competition_settings)
    |> Map.put(:competitions_evaluations, competitions_evaluations)
  end

  defp maybe_duplicate_participants(params, competition, config) do
    if Map.get(config, "participants") == "true" do
      participants = Enum.map(competition.participants, &Map.from_struct/1)
      Map.put(params, :participants, participants)
    else
      Map.put(params, :participants, [])
    end
  end

  defp maybe_duplicate_teams(params, competition, config) do
    if competition.for_teams and Map.get(config, "participants") == "true" and Map.get(config, "teams") == "true" do
      competition = Repo.preload(competition, teams: :members)

      teams =
        Enum.map(competition.teams, fn t ->
          members = Enum.map(t.members, &Map.from_struct/1)

          t
          |> Map.put(:members, members)
          |> Map.from_struct()
        end)

      Map.put(params, :teams, teams)
    else
      Map.put(params, :teams, [])
    end
  end

  defp maybe_duplicate_jurors(params, competition, config) do
    if Map.get(config, "jurors") == "true" do
      jurors = Enum.map(competition.jurors, &Map.from_struct/1)
      Map.put(params, :jurors, jurors)
    else
      Map.put(params, :jurors, [])
    end
  end

  defp maybe_duplicate_slides(params, competition, config) do
    if Map.get(config, "slides") == "true" do
      slides = maybe_duplicate_slide_selection(competition.slides, config)

      Map.put(params, :slides, slides)
    else
      Map.put(params, :slides, [])
    end
  end

  defp maybe_duplicate_slide_selection(slides, config) do
    duplicate_selection? = Map.get(config, "selection") == "true"

    Enum.map(slides, fn s ->
      if duplicate_selection? do
        flags = Enum.map(s.slide_flags, &Map.from_struct/1)
        votes = maybe_duplicate_slide_votes(s.votes, config)

        s
        |> Map.put(:slide_flags, flags)
        |> Map.put(:votes, votes)
        |> Map.from_struct()
      else
        s
        |> Map.put(:subject_id, nil)
        |> Map.put(:status, :discarded)
        |> Map.put(:slide_flags, [])
        |> Map.put(:votes, [])
        |> Map.from_struct()
      end
    end)
  end

  defp maybe_duplicate_slide_votes(votes, config) do
    if Map.get(config, "votes") == "true" do
      Enum.map(votes, &Map.from_struct/1)
    else
      []
    end
  end

  @doc """
  Import a competition.

  ## Examples

  iex> import(%{field: value})
  {:ok, %Competition{}}

  iex> import(%{"field" => "bad_value"})
  {:error, %Ecto.Changeset{}}

  """
  @spec import(%{(String.t() | atom()) => any()}) :: {:error, any()} | {:ok, Competition.t()}
  def import(attrs \\ %{}) do
    settings_changeset =
      CompetitionSettings.changeset(%CompetitionSettings{}, Jason.decode!(attrs["settings"]))

    allowed_evaluations =
      attrs
      |> Map.get("competitions_evaluations", "[]")
      |> Jason.decode!()
      |> Enum.map(&%{"evaluation_id" => &1})

    %Competition{}
    |> Competition.import_changeset(attrs, settings_changeset, allowed_evaluations)
    |> Repo.insert()
    |> notify_subscribers([:competition, :created])
  end

  @doc """
  Updates a competition.

  ## Examples

      iex> update(competition, %{"field" => "new_value"})
      {:ok, %Competition{}}

      iex> update(competition, %{"field" => "bad_value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update(Competition.t(), %{String.t() => any()}) ::
          {:ok, Competition.t()} | {:error, any()}
  def update(%Competition{} = competition, attrs) do
    competition
    |> change(attrs)
    |> Repo.update()
    |> notify_subscribers([:competition, :updated])
  end

  @doc """
  Deletes a Competition.

  ## Examples

      iex> delete(competition)
      {:ok, %Competition{}}

      iex> delete(competition)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete(Competition.t()) :: {:ok, Competition.t()} | {:error, any()}
  def delete(%Competition{} = competition) do
    Multi.new()
    |> Multi.delete(:delete_competition, competition)
    |> Multi.run(:delete_files, fn _repo, %{} ->
      case Slides.delete_files(competition.id) do
        :ok -> {:ok, :deleted}
        {:error, _reason} = error -> error
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delete_competition: competition}} ->
        notify_subscribers({:ok, competition}, [:competition, :deleted])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error("Failed to delete competition. #{failed_operation}: #{inspect(failed_value)}")

        notify_subscribers({:error, {failed_operation, failed_value}}, [:competition, :deleted])
    end
  end

  @doc """
  Deletes many Competitions by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, ["id1", "id2", "id3"]}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, [String.t()]} | :error
  def delete_many(ids) do
    query = from entity in Competition, where: entity.id in ^ids

    Multi.new()
    |> Multi.delete_all(:delete_competitions, query)
    |> Multi.run(:delete_files, fn _repo, %{} ->
      Enum.reduce_while(ids, {:ok, :deleted}, &delete_while/2)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delete_competitions: {_deleted, nil}}} ->
        notify_subscribers({:ok, ids}, [:competition, :deleted])

      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error("Failed to delete competitions. #{failed_operation}: #{inspect(failed_value)}")

        notify_subscribers({:error, {failed_operation, failed_value}}, [:competition, :deleted])
    end
  end

  @doc """
  Deletes all Competitions.

  ## Examples

  iex> delete_all()
  {:ok, 10}

  """
  @spec delete_all :: {:ok, integer()}
  def delete_all do
    {deleted, nil} = Repo.delete_all(Competition)

    notify_subscribers({:ok, deleted}, [:competition, :deleted])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking competition changes.

  ## Examples

  iex> change(competition)
  %Ecto.Changeset{source: %Competition{}}

  """
  @spec change(Competition.t(), map()) :: Ecto.Changeset.t()
  def change(%Competition{} = competition, attrs \\ %{}) do
    attrs =
      cond do
        Map.has_key?(attrs, "settings") or not is_nil(competition.id) ->
          attrs

        Map.has_key?(attrs, :settings) or not is_nil(competition.id) ->
          attrs

        true ->
          Map.put(attrs, "settings", fetch_default_settings())
      end

    Competition.changeset(competition, attrs)
  end

  @spec change_settings(CompetitionSettings.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def change_settings(%CompetitionSettings{} = settings, attrs \\ %{}) do
    CompetitionSettings.changeset(settings, attrs)
  end

  @spec fetch_default_settings :: %{String.t() => any()}
  def fetch_default_settings do
    %{
      "evaluations_per_juror" => fetch_config!(:evaluations_per_juror),
      "number_of_jurors" => fetch_config!(:number_of_jurors),
      "max_jury_slides" => fetch_config!(:max_jury_slides),
      "max_submitted_slides" => fetch_config!(:max_submitted_slides),
      "proportional_submission" => fetch_config!(:proportional_submission),
      "submission_ratio" => fetch_config!(:submission_ratio),
      "fixed_points_multiplier" => fetch_config!(:fixed_points_multiplier),
      "penalty_amount" => fetch_config!(:penalty_amount),
      "dynamic_coefficients" => fetch_config!(:dynamic_coefficients)
    }
  end

  @spec update_allowed_evaluations(String.t(), [String.t()]) ::
          {:ok, Competition.t()} | {:error, any()}
  def update_allowed_evaluations(competition_id, evaluation_ids) do
    evaluations = Enum.map(evaluation_ids, &%{evaluation_id: &1.id})

    {:ok, competition} = get(competition_id)

    competition
    |> Competition.put_allowed_evaluations(evaluations)
    |> Repo.update()
    |> notify_subscribers([:competition, :updated])
  end

  # Internal

  defp delete_while(id, acc) do
    case Slides.delete_files(id) do
      :ok -> {:cont, acc}
      {:error, _reason} = error -> {:halt, error}
    end
  end

  defp fetch_config!(key) do
    config = Application.fetch_env!(:safarimanager, CompetitionSettings)
    defaults = Keyword.fetch!(config, :defaults)

    Keyword.fetch!(defaults, key)
  end
end
