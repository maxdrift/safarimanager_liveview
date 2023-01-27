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

  @spec changeset(t(), %{String.t() => any()}) :: Ecto.Changeset.t()
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
      :organization_id
    ])
    |> validate_required([
      :name,
      :organization_id
    ])
    |> cast_assoc(:settings, required: false)
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
    |> put_assoc(:allowed_evaluations, allowed_evaluations)
  end

  @spec put_allowed_evaluations(t(), [%Evaluation{}]) :: Ecto.Changeset.t()
  def put_allowed_evaluations(struct, evaluations) do
    struct
    |> change()
    |> put_assoc(:allowed_evaluations, evaluations)
  end
end
