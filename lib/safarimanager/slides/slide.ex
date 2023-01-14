defmodule SM.Slides.Slide do
  @moduledoc """
  Slide schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.Competition
  alias SM.Evaluations.Evaluation
  alias SM.Slides.SlideEvaluation
  alias SM.Subjects.Subject

  @statuses Application.compile_env!(:safarimanager, [__MODULE__, :statuses])

  defmodule WrongSubjectContext do
    @moduledoc false
    use SM, :schema

    @primary_key false
    @derive {Jason.Encoder, except: [:__struct__]}
    embedded_schema do
      field :from, Ecto.UUID
      field :to, Ecto.UUID
    end

    @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
    def changeset(flags, attrs) do
      cast(flags, attrs, [:from, :to])
    end
  end

  defmodule Flags do
    @moduledoc """
    Slides flags embedded schema
    """
    use SM, :schema
    alias SM.Slides.Slide.WrongSubjectContext

    @primary_key false
    @derive {Jason.Encoder, except: [:__struct__]}
    embedded_schema do
      field :wrong_subject, :boolean, default: false
      embeds_one :wrong_subject_ctx, WrongSubjectContext, on_replace: :update
      field :other_reason, :boolean, default: false
      field :other_reason_ctx, :string
    end

    @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
    def changeset(flags, attrs) do
      flags
      |> cast(attrs, [
        :wrong_subject,
        :other_reason,
        :other_reason_ctx
      ])
      |> cast_embed(:wrong_subject_ctx)
    end
  end

  schema "slides" do
    field :file_name, :string
    field :file_size, :integer
    field :file_type, :string
    field :file_hash, :string
    field :width, :integer
    field :height, :integer
    field :metadata, :map
    field :status, Ecto.Enum, values: @statuses
    field :penalty, :boolean
    embeds_one :flags, Flags, on_replace: :update
    belongs_to :user, User
    belongs_to :competition, Competition
    belongs_to :subject, Subject
    many_to_many :evaluations, Evaluation, join_through: SlideEvaluation

    timestamps()
  end

  @doc false
  @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(slide, attrs) do
    slide
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
    |> cast_embed(:flags)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:subject_id)
  end

  @spec get_statuses :: [:discarded | :submitted_jury | :submitted_fixed, ...]
  def get_statuses do
    @statuses
  end
end
