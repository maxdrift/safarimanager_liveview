defmodule SM.CompetitionDirectories.CompetitionDirectory do
  @moduledoc """
  Links a competition to a host-local directory tree for linked slide originals.

  See `docs/IMAGE_STORAGE.md`.
  """
  use SM, :schema

  alias SM.Competitions.Competition

  @primary_key {:competition_id, Ecto.UUID, autogenerate: false}

  schema "competition_directories" do
    field :library_id, Ecto.UUID
    field :root_path, :string

    belongs_to :competition, Competition,
      define_field: false,
      foreign_key: :competition_id,
      type: Ecto.UUID

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:competition_id, :library_id, :root_path])
    |> validate_required([:competition_id, :library_id, :root_path])
    |> foreign_key_constraint(:competition_id)
    |> unique_constraint(:competition_id)
  end
end
