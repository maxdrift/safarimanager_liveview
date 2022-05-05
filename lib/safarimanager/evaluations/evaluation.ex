defmodule SM.Evaluations.Evaluation do
  @moduledoc """
  Evaluation database schema
  """
  use SM, :schema

  @types Application.compile_env!(:safarimanager, [__MODULE__, :types])

  schema "evaluations" do
    field :description, :string
    field :type, Ecto.Enum, values: @types, default: :numeric
    field :value, :decimal

    timestamps()
  end

  @spec changeset(Evaluation.t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(evaluation, attrs) do
    evaluation
    |> cast(attrs, [:value, :type, :description])
    |> validate_required([:value])
  end

  @spec get_types :: [:numeric, ...]
  def get_types do
    @types
  end
end
