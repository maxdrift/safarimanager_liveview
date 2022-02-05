defmodule SM.Subjects.Subject do
  @moduledoc """
  Subjects schema
  """
  use SM, :schema

  @available_types Application.compile_env!(:safarimanager, [__MODULE__, :available_types])

  schema "subjects" do
    field :name, :string
    field :coefficient, :integer
    field :numeric_id, :integer
    field :scientific_name, :string
    field :type, Ecto.Enum, values: @available_types

    timestamps()
  end

  @doc false
  @spec changeset(t(), %{String.t() => any()}) :: Ecto.Changeset.t()
  def changeset(subject, attrs) do
    subject
    |> cast(attrs, [:name, :coefficient, :numeric_id, :scientific_name, :type])
    |> validate_required([:name, :numeric_id, :type])
    |> unique_constraint(:numeric_id)
  end

  @spec get_available_types :: [:ambient | :fish | :fish_macro | :macro, ...]
  def get_available_types do
    @available_types
  end
end
