defmodule SM.Evaluations.Evaluation do
  @moduledoc """
  Evaluation database schema
  """
  use SM, :schema

  schema "evaluations" do
    field :description, :string
    field :type, :string
    field :value, :decimal

    timestamps()
  end

  @spec changeset(Evaluation.t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def changeset(evaluation, attrs) do
    evaluation
    |> cast(attrs, [:value, :type, :description])
    |> validate_required([:value])
  end
end
