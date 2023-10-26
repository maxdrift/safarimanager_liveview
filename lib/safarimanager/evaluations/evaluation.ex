defmodule SM.Evaluations.Evaluation do
  @moduledoc """
  Evaluation database schema
  """
  use SM, :schema

  @types Application.compile_env!(:safarimanager, [__MODULE__, :types])

  schema "evaluations" do
    field :name, :string
    field :description, :string
    field :type, Ecto.Enum, values: @types, default: :numeric
    field :value, :decimal
    field :is_penalty, :boolean

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :value, :is_penalty, :type, :description])
    |> validate_required([:name, :value])
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required(__MODULE__.__schema__(:fields) -- [:is_penalty, :description])
    |> unique_constraint(:id)
  end

  @spec get_types :: [:numeric | :boolean, ...]
  def get_types do
    @types
  end
end
