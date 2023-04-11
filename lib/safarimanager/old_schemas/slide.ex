defmodule SM.OldSchemas.Slide do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :nomefile, :string
    field :ID_pesce, :integer
    field :v1, :integer
    field :v2, :integer
    field :v3, :integer
    field :pen, :boolean
    field :pres, :boolean
    field :flag, :boolean
    field :punti, :integer
    field :ID_concorrente, :integer
  end

  @required_fields ~w(id nomefile ID_pesce v1 v2 v3 pen pres flag punti ID_concorrente)a
  @fields @required_fields

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
