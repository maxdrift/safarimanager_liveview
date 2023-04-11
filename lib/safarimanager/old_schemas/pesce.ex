defmodule SM.OldSchemas.Pesce do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :ID, :integer
    field :nome, :string
    field :coeff, :integer
    # Most recent fields
    field :coeff_dinamico, :integer
    field :nome_scientifico, :string
    field :distribuzione, :integer
  end

  @required_fields ~w(ID nome coeff)a
  @fields @required_fields ++ ~w(coeff_dinamico nome_scientifico distribuzione)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
