defmodule SM.Repo.Migrations.CreateCompetitionSettings do
  use Ecto.Migration

  def change do
    create table(:competition_settings, primary_key: false) do
      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :evaluations_per_juror, :integer, null: false
      add :number_of_jurors, :integer, null: false
      add :max_jury_slides, :integer, null: false
      add :max_submitted_slides, :integer, null: false
      add :proportional_submission, :boolean, null: false
      add :submission_ratio, :decimal, null: false
      add :fixed_points_multiplier, :decimal, null: false
      add :penalty_amount, :decimal, null: false
      add :dynamic_coefficients, :map

      timestamps()
    end
  end
end
