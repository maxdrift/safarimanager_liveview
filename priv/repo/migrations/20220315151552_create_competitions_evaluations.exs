defmodule SM.Repo.Migrations.CreateCompetitionsEvaluations do
  use Ecto.Migration

  def change do
    create table(:competitions_evaluations, primary_key: false) do
      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :evaluation_id, references(:evaluations, on_delete: :delete_all, type: :binary_id),
        primary_key: true
    end

    create index(:competitions_evaluations, [:competition_id])
    create index(:competitions_evaluations, [:evaluation_id])
  end
end
