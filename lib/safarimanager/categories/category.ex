defmodule SM.Categories.Category do
  @moduledoc """
  Category DB schema
  """
  use SM, :schema

  @camera_types Application.compile_env(:safarimanager, [__MODULE__, :camera_types])

  schema "categories" do
    field :name, :string
    field :camera_type, Ecto.Enum, values: @camera_types

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :camera_type])
    |> validate_required([:name, :camera_type])
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required([:id, :name, :camera_type])
    |> unique_constraint(:id)
  end

  @spec get_camera_types :: [:any | :compact | :reflex, ...]
  def get_camera_types do
    @camera_types
  end
end
