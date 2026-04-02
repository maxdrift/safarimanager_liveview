defmodule SM.Competitions.CompetitionSubject do
  @moduledoc """
  Per-competition subject allow-list and static coefficient override.
  """
  use SM, :schema

  alias SM.Competitions.Competition
  alias SM.Subjects.Subject

  schema "competition_subjects" do
    field :coefficient, :integer, default: 0

    belongs_to :competition, Competition
    belongs_to :subject, Subject

    timestamps()
  end

  @doc false
  @spec changeset(t(), map(), non_neg_integer()) :: Ecto.Changeset.t()
  def changeset(struct, attrs, _position \\ 0) do
    struct
    |> cast(attrs, [:competition_id, :subject_id, :coefficient])
    |> validate_required([:subject_id, :coefficient])
    |> validate_number(:coefficient, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:subject_id)
    |> unique_constraint([:competition_id, :subject_id],
      name: :competition_subjects_competition_id_subject_id_index
    )
  end
end
