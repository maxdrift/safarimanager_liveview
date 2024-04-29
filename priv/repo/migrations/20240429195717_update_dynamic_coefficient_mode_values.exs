defmodule SM.Repo.Migrations.UpdateDynamicCoefficientModeValues do
  use Ecto.Migration

  def change do
    execute(
      """
      UPDATE competition_settings SET dynamic_coefficient_mode = 'all' WHERE dynamic_coefficients_enabled IS true
      """,
      """
      UPDATE competition_settings SET dynamic_coefficients_enabled = true WHERE dynamic_coefficient_mode = 'all';
      UPDATE competition_settings SET dynamic_coefficient_mode = 'disabled'
      """
    )
  end
end
