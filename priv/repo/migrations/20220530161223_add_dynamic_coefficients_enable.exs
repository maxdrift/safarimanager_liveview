defmodule SM.Repo.Migrations.AddDynamicCoefficientsEnable do
  use Ecto.Migration

  def up do
    execute """
    PRAGMA foreign_keys = 0;
    """

    execute """
    CREATE TABLE competition_settings_tmp AS
    SELECT
        *
    FROM
        competition_settings;
    """

    execute """
    DROP TABLE competition_settings;
    """

    execute """
    CREATE TABLE competition_settings (
        competition_id TEXT_UUID PRIMARY KEY CONSTRAINT competition_settings_tmp_competition_id_fkey REFERENCES competitions (id) ON DELETE CASCADE,
        evaluations_per_juror INTEGER NOT NULL,
        number_of_jurors INTEGER NOT NULL,
        max_jury_slides INTEGER NOT NULL,
        max_submitted_slides INTEGER NOT NULL,
        proportional_submission BOOLEAN NOT NULL,
        submission_ratio DECIMAL NOT NULL,
        fixed_points_multiplier DECIMAL NOT NULL,
        penalty_amount DECIMAL NOT NULL,
        dynamic_coefficients JSON,
        inserted_at TEXT_DATETIME NOT NULL,
        updated_at TEXT_DATETIME NOT NULL,
        dynamic_coefficients_enabled BOOLEAN NOT NULL
    );
    """

    execute """
    INSERT INTO
        competition_settings (
            competition_id,
            evaluations_per_juror,
            number_of_jurors,
            max_jury_slides,
            max_submitted_slides,
            proportional_submission,
            submission_ratio,
            fixed_points_multiplier,
            penalty_amount,
            dynamic_coefficients,
            dynamic_coefficients_enabled,
            inserted_at,
            updated_at
        )
    SELECT
        competition_id,
        evaluations_per_juror,
        number_of_jurors,
        max_jury_slides,
        max_submitted_slides,
        proportional_submission,
        submission_ratio,
        fixed_points_multiplier,
        penalty_amount,
        dynamic_coefficients,
        FALSE,
        inserted_at,
        updated_at
    FROM
        competition_settings_tmp;
    """

    execute """
    DROP TABLE competition_settings_tmp;
    """

    execute """
    PRAGMA foreign_keys = 1;
    """
  end

  def down do
    alter table(:competition_settings) do
      remove :dynamic_coefficients_enabled
    end
  end
end
