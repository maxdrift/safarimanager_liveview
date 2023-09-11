defmodule SM.Teams.TeamMember do
  @moduledoc """
  Team Member schema
  """
  use SM, :schema

  alias SM.Accounts.User
  alias SM.Competitions.Competition
  alias SM.Teams.Team

  schema "team_members" do
    field :position, :integer
    belongs_to :team, Team, primary_key: true
    belongs_to :competition, Competition, primary_key: true
    belongs_to :user, User, primary_key: true

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:team_id, :competition_id, :user_id, :position])
    |> validate_required([:competition_id, :user_id])
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:team, :competition, :user],
      name: "team_members_team_id_competition_id_user_id_index"
    )
  end

  @doc false
  @spec changeset(t(), map(), integer()) :: Ecto.Changeset.t()
  def changeset(struct, attrs, position) do
    struct
    |> cast(attrs, [:team_id, :competition_id, :user_id])
    |> validate_required([:competition_id, :user_id])
    |> change(position: position)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:competition_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:team, :competition, :user],
      name: "team_members_team_id_competition_id_user_id_index"
    )
  end
end
