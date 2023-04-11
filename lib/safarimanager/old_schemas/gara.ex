defmodule SM.OldSchemas.Gara do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :denom, :string
    field :organizz, :string
    field :data, :date
    field :luogo, :string
    field :tipo, :string
    field :nspeciep, :integer
    field :penalty, :integer
    field :totspecie, :integer
    field :cartella, :string
    # Most recent fields
    field :moltpuntfisso, :integer
    field :pspeciep, :integer
    field :percentuale, :boolean
    field :coeff_min, :integer
    field :coeff_med, :integer
    field :coeff_max, :integer
  end

  @required_fields ~w(id denom organizz data luogo tipo nspeciep penalty totspecie)a
  @fields @required_fields ++
            ~w(cartella moltpuntfisso pspeciep percentuale coeff_min coeff_med coeff_max)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
