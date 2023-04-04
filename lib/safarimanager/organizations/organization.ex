defmodule SM.Organizations.Organization do
  @moduledoc """
  Organization DB schema
  """
  use SM, :schema

  schema "organizations" do
    field :name, :string
    field :location, :string

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :location])
    |> validate_required([:name])
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required([:id, :name])
    |> unique_constraint(:id)
  end
end
