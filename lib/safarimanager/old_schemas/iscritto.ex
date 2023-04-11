defmodule SM.OldSchemas.Iscritto do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :ID, :integer
    field :lettera, :string
    field :nome, :string
    field :cognome, :string
    field :squadra, :boolean
    field :ID_societa, :integer
    field :ID_categoria, :integer
    field :nomecartella, :string
  end

  @required_fields ~w(ID lettera cognome squadra ID_societa ID_categoria)a
  @fields @required_fields ++ ~w(nome nomecartella)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
