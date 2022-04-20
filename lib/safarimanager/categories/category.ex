defmodule SM.Categories.Category do
  @moduledoc """
  Category DB schema
  """
  use SM, :schema

  schema "categories" do
    field :name, :string

    timestamps()
  end

  @doc false
  @spec changeset(SM.Categories.Category.t(), map()) :: Ecto.Changeset.t()
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
