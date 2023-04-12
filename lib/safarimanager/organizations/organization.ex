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
  @spec merge_changeset([String.t()], String.t()) :: Ecto.Changeset.t()
  def merge_changeset(source_ids, dest_id) do
    {%{}, %{source_ids: {:array, :string}, dest_id: :string}}
    |> cast(%{source_ids: source_ids, dest_id: dest_id}, [:source_ids, :dest_id])
    |> validate_required([:source_ids, :dest_id])
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
