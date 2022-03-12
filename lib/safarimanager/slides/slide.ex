defmodule SM.Slides.Slide do
  @moduledoc """
  Slide schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.Competition
  alias SM.Subjects.Subject

  @statuses Application.compile_env!(:safarimanager, [__MODULE__, :statuses])

  schema "slides" do
    field :file_name, :string
    field :file_size, :integer
    field :file_type, :string
    field :file_hash, :string
    field :status, Ecto.Enum, values: @statuses
    belongs_to :user, User
    belongs_to :competition, Competition
    belongs_to :subject, Subject

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
      :status,
      :user_id,
      :competition_id,
      :subject_id
    ])
    |> validate_required([:file_name, :file_size, :user_id, :competition_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:subject_id)
  end

  @spec get_statuses :: [:discarded | :submitted_jury | :submitted_fixed, ...]
  def get_statuses do
    @statuses
  end
end
