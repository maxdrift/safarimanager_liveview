defmodule SM.Competitions do
  @moduledoc """
  The Competitions context.
  """
  use SM, :context

  alias SM.Competitions.Competition
  alias SM.Competitions.CompetitionSettings
  alias SM.Evaluations
  alias SM.Evaluations.Evaluation

  @doc """
  Returns the list of competition types.

  ## Examples

  iex> list_competition_types()
  [:qualification, :national_championship, :international_championship, :local_event, :national_event, :international_event]

  """
  @spec list_competition_types :: [
          :qualification
          | :national_championship
          | :international_championship
          | :local_event
          | :national_event
          | :international_event,
          ...
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
    |> Repo.preload([:organization])
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
           [participants: [:organization, :category]],
           [jurors: :organization],
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
  @spec create(%{String.t() => any()}) :: {:error, any()} | {:ok, Competition.t()}
  def create(attrs \\ %{}) do
    %Competition{}
    |> change(attrs)
    |> Repo.insert()
    |> notify_subscribers([:competition, :created])
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
      |> Map.get("allowed_evaluations", "[]")
      |> Jason.decode!()
      |> Enum.flat_map(fn e ->
        case Repo.get(Evaluation, e) do
          nil -> []
          result -> [result]
        end
      end)

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
    competition
    |> Repo.delete()
    |> notify_subscribers([:competition, :deleted])
  end

  @doc """
  Deletes many Competitions by ID.

  ## Examples

  iex> delete_many(["id1", "id2", "id3"])
  {:ok, 3}

  iex> delete_many(["id1", "id2", "id3"])
  :error

  """
  @spec delete_many([String.t()]) :: {:ok, integer()} | :error
  def delete_many(ids) do
    {deleted, nil} = Repo.delete_all(from entity in Competition, where: entity.id in ^ids)

    if deleted == Enum.count(ids) do
      notify_subscribers({:ok, deleted}, [:competition, :deleted])
    else
      notify_subscribers(:error, [:competition, :deleted])
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking competition changes.

  ## Examples

  iex> change(competition)
  %Ecto.Changeset{source: %Competition{}}

  """
  @spec change(Competition.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
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
    evaluations = Evaluations.list_by_ids(evaluation_ids)

    {:ok, competition} = get(competition_id)

    competition
    |> Competition.put_allowed_evaluations(evaluations)
    |> Repo.update()
    |> notify_subscribers([:competition, :updated])
  end

  # Internal

  defp fetch_config!(key) do
    config = Application.fetch_env!(:safarimanager, CompetitionSettings)
    defaults = Keyword.fetch!(config, :defaults)

    Keyword.fetch!(defaults, key)
  end
end
