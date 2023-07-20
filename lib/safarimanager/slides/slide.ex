defmodule SM.Slides.Slide do
  @moduledoc """
  Slide schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.Competition
  alias SM.Evaluations.Evaluation
  alias SM.Slides.SlideEvaluation
  alias SM.Slides.SlideFlag
  alias SM.Subjects.Subject

  @statuses Application.compile_env!(:safarimanager, [__MODULE__, :statuses])

  schema "slides" do
    field :file_name, :string
    field :file_size, :integer
    field :file_type, :string
    field :file_hash, :string
    field :width, :integer
    field :height, :integer
    field :metadata, :map
    field :status, Ecto.Enum, values: @statuses, default: :discarded
    field :penalty, :boolean
    has_many :slide_flags, SlideFlag
    belongs_to :user, User
    belongs_to :competition, Competition
    belongs_to :subject, Subject
    many_to_many :evaluations, Evaluation, join_through: SlideEvaluation

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :file_name,
      :file_size,
      :file_type,
      :file_hash,
      :width,
      :height,
      :metadata,
      :status,
      :penalty,
      :user_id,
      :competition_id,
      :subject_id
    ])
    |> validate_required([:file_name, :file_size, :user_id, :competition_id])
    |> maybe_require_subject()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:subject_id)
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required([:id, :file_name, :file_size, :user_id, :competition_id])
    |> maybe_require_subject()
    |> unique_constraint(:id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:subject_id)
  end

  @spec get_statuses :: [:discarded | :submitted_jury | :submitted_fixed, ...]
  def get_statuses do
    @statuses
  end

  # Internal

  defp maybe_require_subject(changeset) do
    if get_field(changeset, :status) != :discarded do
      validate_required(changeset, [:subject_id])
    else
      changeset
    end
  end
end
