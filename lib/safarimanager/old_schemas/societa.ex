defmodule SM.OldSchemas.Societa do
  @moduledoc false
  use SM, :schema

  @primary_key false
  embedded_schema do
    field :ID, :integer
    field :nomes, :string
    field :luogos, :string
    field :componenti, :string
  end

  @required_fields ~w(ID nomes luogos )a
  @fields @required_fields ++ ~w(componenti)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
