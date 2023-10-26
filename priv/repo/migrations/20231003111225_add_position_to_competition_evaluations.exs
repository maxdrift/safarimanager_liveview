defmodule SM.Repo.Migrations.AddPositionToCompetitionEvaluations do
  use Ecto.Migration

  def change do
    alter table(:competitions_evaluations) do
      add :position, :integer
    end
  end
end
