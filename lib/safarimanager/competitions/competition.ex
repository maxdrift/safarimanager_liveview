defmodule SM.Competitions.Competition do
  @moduledoc """
  Competition schema
  """
  use SM, :schema

  alias SM.Accounts.User
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
    field :req_jurors_count, :integer, default: 0
    field :evaluations_per_juror, :integer, default: 0
    belongs_to :organization, Organization
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
      :req_jurors_count,
      :evaluations_per_juror,
      :organization_id
    ])
    |> validate_required([
      :name,
      :organization_id
    ])
    |> put_assoc(:allowed_evaluations, Map.get(attrs, "allowed_evaluations", []))
  end

  @spec update_changeset(Competition.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def update_changeset(competition, attrs) do
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
      :req_jurors_count,
      :evaluations_per_juror,
      :organization_id
    ])
    |> validate_required([
      :name,
      :organization_id
    ])
  end
end
