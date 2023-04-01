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

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:value, :type, :description])
    |> validate_required([:value])
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required(__MODULE__.__schema__(:fields) -- [:description])
    |> unique_constraint(:id)
  end

  @spec get_types :: [:numeric, ...]
  def get_types do
    @types
  end
end
