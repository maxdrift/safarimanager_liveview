defmodule SM.Teams.Team do
  @moduledoc """
  Team schema
  """
  use SM, :schema

  import SMWeb.Gettext

  alias SM.Competitions.Competition
  alias SM.Teams.TeamMember

  schema "teams" do
    field :name, :string
    field :organization_name, :string
    field :number, :integer
    belongs_to :competition, Competition

    has_many :members, TeamMember, preload_order: [asc: :position], on_replace: :delete
    has_many :users, through: [:members, :user]

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :organization_name, :competition_id, :number])
    |> validate_required([:competition_id, :number])
    |> cast_assoc(:members,
      with: &TeamMember.changeset/3,
      sort_param: :members_sort,
      drop_param: :members_drop,
      required: true
    )
    |> validate_team_member()
    |> validate_number(:number, greater_than: 0)
    |> foreign_key_constraint(:competition_id)
    |> unique_constraint([:competition_id, :number],
      name: :teams_competition_id_number_index
    )
  end

  defp validate_team_member(changeset) do
    validate_change(changeset, :members, fn :members, members ->
      user_ids =
        members
        |> Enum.map(fn changeset -> get_change(changeset, :user_id) end)
        |> Enum.reject(&is_nil(&1))

      unique_user_ids = Enum.uniq(user_ids)
      duplicates = Enum.uniq(user_ids -- unique_user_ids)

      if duplicates != [] do
        [
          members: {dgettext("errors", "is already a member of this team"), user_id: hd(duplicates)}
        ]
      else
        []
      end
    end)
  end

  @doc false
  @spec import_changeset(t(), map()) :: Ecto.Changeset.t()
  def import_changeset(struct, attrs) do
    struct
    |> cast(attrs, __MODULE__.__schema__(:fields))
    |> validate_required([:id])
    |> unique_constraint(:id)
  end
end
