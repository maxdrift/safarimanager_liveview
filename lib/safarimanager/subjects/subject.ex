defmodule SM.Subjects.Subject do
  @moduledoc """
  Subject schema
  """
  use SM, :schema

  @types Application.compile_env!(:safarimanager, [__MODULE__, :types])
  @coefficients Application.compile_env!(:safarimanager, [__MODULE__, :coefficients])

  schema "subjects" do
    field :name, :string
    field :coefficient, :integer
    field :numeric_id, :integer
    field :scientific_name, :string
    field :type, Ecto.Enum, values: @types

    timestamps()
  end

  @doc false
  @spec changeset(t(), %{(String.t() | atom()) => any()}) :: Ecto.Changeset.t()
  def changeset(subject, attrs) do
    subject
    |> cast(attrs, [:name, :coefficient, :numeric_id, :scientific_name, :type])
    |> validate_required([:name, :numeric_id, :type])
    |> validate_inclusion(:coefficient, @coefficients)
    |> unique_constraint(:numeric_id)
  end

  @spec get_types :: [:ambient | :fish | :fish_macro | :macro, ...]
  def get_types do
    @types
  end

  @spec get_coefficients :: [2 | 4 | 6, ...]
  def get_coefficients do
    @coefficients
  end
end
