defmodule SM.Competitions.Competition do
  @moduledoc """
  Competition schema
  """
  use SM, :schema

  alias SM.Competitions.CompetitionEvaluation
  alias SM.Competitions.CompetitionSettings
  alias SM.Evaluations.Evaluation
  alias SM.Jurors.Juror
  alias SM.Organizations.Organization
  alias SM.Participants.Participant
  alias SM.Slides.Slide
  alias SM.Teams.Team

  @types Application.compile_env!(:safarimanager, [__MODULE__, :types])

  schema "competitions" do
    field :name, :string
    field :start_time, :utc_datetime_usec
    field :end_time, :utc_datetime_usec
    field :street_name, :string
    field :street_number, :string
    field :postal_code, :string
    field :city, :string
    field :state, :string
    field :country, :string
    field :type, Ecto.Enum, values: Keyword.keys(@types)
    field :for_teams, :boolean, default: false

    belongs_to :organization, Organization

    has_one :settings, CompetitionSettings, on_replace: :delete
    has_many :competitions_evaluations, CompetitionEvaluation, on_replace: :delete
    has_many :allowed_evaluations, through: [:competitions_evaluations, :evaluation]
    has_many :participants, Participant, preload_order: [asc: :number], on_replace: :delete
    has_many :teams, Team
    has_many :jurors, Juror, preload_order: [asc: :inserted_at], on_replace: :delete
    has_many :slides, Slide

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :name,
      :start_time,
      :end_time,
      :street_name,
      :street_number,
      :postal_code,
      :city,
      :state,
      :country,
      :type,
      :for_teams,
      :organization_id
    ])
    |> validate_required([
      :name,
      :organization_id,
      :type
    ])
    |> cast_assoc(:settings, required: false)
    |> cast_assoc(:competitions_evaluations, required: false)
    |> validate_dates()
  end

  @spec duplication_changeset(t(), map()) :: Ecto.Changeset.t()
  def duplication_changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :name,
      :start_time,
      :end_time,
      :street_name,
      :street_number,
      :postal_code,
      :city,
      :state,
      :country,
      :type,
      :for_teams,
      :organization_id
    ])
    |> validate_required([
      :name,
      :organization_id,
      :type
    ])
    |> cast_assoc(:settings, required: false)
    |> cast_assoc(:competitions_evaluations, required: false)
    |> cast_assoc(:participants, required: false)
    |> cast_assoc(:jurors, required: false)
    |> cast_assoc(:slides, required: false)
    |> cast_assoc(:teams, required: false)
    |> validate_dates()
  end

  @doc false
  @spec import_changeset(t(), map(), Ecto.Changeset.t(), [Evaluation.t()]) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs, settings_changeset, allowed_evaluations) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required([:id, :name, :organization_id])
    |> unique_constraint(:id)
    |> foreign_key_constraint(:organization_id)
    |> put_assoc(:settings, settings_changeset)
    |> put_assoc(:competitions_evaluations, allowed_evaluations)
  end

  @spec put_allowed_evaluations(t(), [Evaluation.t()]) :: Ecto.Changeset.t()
  def put_allowed_evaluations(struct, evaluations) do
    struct
    |> change()
    |> put_assoc(:competitions_evaluations, evaluations)
  end

  @spec get_types :: [
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
  def get_types do
    @types
  end

  # Internal

  defp validate_dates(changeset) do
    with start_time when not is_nil(start_time) <- get_field(changeset, :start_time),
         end_time when not is_nil(end_time) <- get_field(changeset, :end_time),
         :gt <- Date.compare(start_time, end_time) do
      add_error(changeset, :starts_on, "cannot be later than 'end_time'")
    else
      _other -> changeset
    end
  end
end
