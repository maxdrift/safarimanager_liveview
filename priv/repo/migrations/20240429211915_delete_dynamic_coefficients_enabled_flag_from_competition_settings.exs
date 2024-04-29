defmodule SM.Repo.Migrations.DeleteDynamicCoefficientsEnabledFlagFromCompetitionSettings do
  use Ecto.Migration

  def up do
    alter table(:competition_settings) do
      remove :dynamic_coefficients_enabled
    end
  end

  def down do
    alter table(:competition_settings) do
      add :dynamic_coefficients_enabled, :boolean, default: false
    end
  end
end
