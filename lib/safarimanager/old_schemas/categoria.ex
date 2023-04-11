defmodule SM.OldSchemas.Categoria do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :ID, :integer
    field :categoria, :string
    field :nomecartella, :string
  end

  @required_fields ~w(ID categoria)a
  @fields @required_fields ++ ~w(nomecartella)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
