defmodule SM.Repo.Migrations.CreateCompetitionSubjects do
  use Ecto.Migration

  def change do
    create table(:competition_subjects, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id),
        null: false

      add :subject_id, references(:subjects, on_delete: :nothing, type: :binary_id), null: false
      add :coefficient, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:competition_subjects, [:competition_id, :subject_id])
    create index(:competition_subjects, [:subject_id])
  end
end
