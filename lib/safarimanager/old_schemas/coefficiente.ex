defmodule SM.OldSchemas.Coefficiente do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :ID, :integer
    field :grado, :string
    field :valore, :integer
    field :soglia_inf, :integer
    field :soglia_sup, :integer
  end

  @required_fields ~w(ID grado valore soglia_inf soglia_sup)a
  @fields @required_fields

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
