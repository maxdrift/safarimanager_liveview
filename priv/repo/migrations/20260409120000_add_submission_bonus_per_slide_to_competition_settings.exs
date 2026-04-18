defmodule SM.Repo.Migrations.AddSubmissionBonusPerSlideToCompetitionSettings do
  use Ecto.Migration

  def change do
    alter table(:competition_settings) do
      add :submission_bonus_per_slide, :decimal, null: false, default: 0
    end
  end
end
