defmodule SM.Repo.Migrations.AddForTeamsFlagToCompetitions do
  use Ecto.Migration

  def change do
    alter table(:competitions) do
      add :for_teams, :boolean, null: false, default: false
    end
  end
end
