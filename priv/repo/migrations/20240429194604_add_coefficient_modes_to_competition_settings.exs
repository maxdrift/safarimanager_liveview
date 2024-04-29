defmodule SM.Repo.Migrations.AddCoefficientModesToCompetitionSettings do
  use Ecto.Migration

  def change do
    alter table(:competition_settings) do
      add :coefficient_mode, :string, default: "all"
      add :dynamic_coefficient_mode, :string, default: "disabled"
    end
  end
end
