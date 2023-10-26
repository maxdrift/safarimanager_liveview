defmodule SM.Repo.Migrations.AddBooleanValueAndNameToEvaluations do
  use Ecto.Migration

  def change do
    alter table(:evaluations) do
      add :name, :string
      add :boolean_value, :boolean, null: false, default: false
    end
  end
end
