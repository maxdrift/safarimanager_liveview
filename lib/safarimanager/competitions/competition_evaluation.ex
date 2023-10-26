defmodule SM.Competitions.CompetitionEvaluation do
  @moduledoc """
  CompetitionEvaluation schema
  """
  use SM, :schema

  alias SM.Competitions.Competition
  alias SM.Evaluations.Evaluation

  @primary_key false
  schema "competitions_evaluations" do
    field :position, :integer
    belongs_to :competition, Competition, primary_key: true
    belongs_to :evaluation, Evaluation, primary_key: true
  end

  @doc false
  @spec changeset(t(), map(), integer()) :: Ecto.Changeset.t()
  def changeset(struct, attrs, position) do
    struct
    |> cast(attrs, [:competition_id, :evaluation_id])
    |> validate_required([:evaluation_id])
    |> change(position: position)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:evaluation_id)
    |> unique_constraint([:competition, :evaluation],
      name: "competitions_evaluations_competition_id_evaluation_id_index"
    )
  end
end
