defmodule SM.Participants.Participant do
  @moduledoc """
  Participant schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Categories.Category
  alias SM.Competitions.Competition

  @primary_key false
  schema "participants" do
    belongs_to :user, User, primary_key: true
    belongs_to :competition, Competition, primary_key: true
    belongs_to :category, Category
    field :number, :integer
    field :originals_folder, :string
    field :slides_count, :integer, virtual: true

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :competition_id, :category_id, :number])
    |> validate_required([:user_id, :competition_id, :category_id, :number])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:user, :competition], name: :participants_user_id_competition_id_index)
    |> unique_constraint([:competition, :number], name: :participants_competition_id_number_index)
  end

  @spec changeset(t(), map(), integer()) :: Ecto.Changeset.t()
  def changeset(struct, attrs, number) do
    struct
    |> cast(attrs, [:user_id, :competition_id, :category_id])
    |> validate_required([:user_id, :competition_id, :category_id])
    |> change(number: number)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:user, :competition], name: :participants_user_id_competition_id_index)
    |> unique_constraint([:competition, :number], name: :participants_competition_id_number_index)
  end

  @doc """
  Sets the originals folder, relative to the competition directory root.
  Only `SM.CompetitionDirectories` should call this, after validating the path.
  """
  @spec folder_changeset(t(), String.t() | nil) :: Ecto.Changeset.t()
  def folder_changeset(struct, relative_folder) do
    change(struct, originals_folder: relative_folder)
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required(__MODULE__.__schema__(:fields) -- [:originals_folder])
    |> validate_change(:originals_folder, &validate_relative_folder/2)
    |> unique_constraint(:id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:user, :competition], name: :participants_user_id_competition_id_index)
    |> unique_constraint([:competition, :number], name: :participants_competition_id_number_index)
  end

  defp validate_relative_folder(field, folder) do
    if Path.type(folder) == :relative and ".." not in Path.split(folder) do
      []
    else
      [{field, "must be a folder inside the competition directory"}]
    end
  end
end
