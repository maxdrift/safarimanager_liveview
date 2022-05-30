defmodule SM.Competitions.Competition do
  @moduledoc """
  Competition schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.CompetitionSettings
  alias SM.Evaluations.Evaluation
  alias SM.Jurors.Juror
  alias SM.Organizations.Organization
  alias SM.Participants.Participant
  alias SM.Slides.Slide

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

    belongs_to :organization, Organization

    has_one :settings, CompetitionSettings, on_replace: :delete
    many_to_many :allowed_evaluations, Evaluation, join_through: "competitions_evaluations"
    many_to_many :participants, User, join_through: Participant
    many_to_many :jurors, User, join_through: Juror
    has_many :slides, Slide

    timestamps()
  end

  @spec changeset(Competition.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def changeset(competition, attrs) do
    competition
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
      :organization_id
    ])
    |> validate_required([
      :name,
      :organization_id
    ])
    |> cast_assoc(:settings, required: false)
  end

  @spec put_allowed_evaluations(Competition.t(), [%Evaluation{}]) :: Ecto.Changeset.t()
  def put_allowed_evaluations(competition, evaluations) do
    competition
    |> change()
    |> put_assoc(:allowed_evaluations, evaluations)
  end
end
