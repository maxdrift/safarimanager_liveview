defmodule SM.Repo.Migrations.CreateSlidesEvaluations do
  use Ecto.Migration

  def change do
    create table(:slides_evaluations, primary_key: false) do
      add :slide_id, references(:slides, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :evaluation_id, references(:evaluations, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:slides_evaluations, [:slide_id])
    create index(:slides_evaluations, [:user_id])
    create index(:slides_evaluations, [:evaluation_id])
  end
end
