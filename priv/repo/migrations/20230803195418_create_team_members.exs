defmodule SM.Repo.Migrations.CreateTeamMembers do
  use Ecto.Migration

  def change do
    create table(:team_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:teams, on_delete: :delete_all, type: :binary_id)
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :position, :integer, null: false

      timestamps()
    end

    create unique_index(:team_members, [:team_id, :user_id])
  end
end
