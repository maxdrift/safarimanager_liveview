defmodule SM.Organizations.Organization do
  @moduledoc """
  Organization DB schema
  """
  use SM, :schema

  schema "organizations" do
    field :name, :string

    timestamps()
  end

  @doc false
  @spec changeset(SM.Organizations.Organization.t(), map()) :: Ecto.Changeset.t()
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
