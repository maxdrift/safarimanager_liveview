defmodule SM.Repo.Migrations.CreateEvaluations do
  use Ecto.Migration

  def change do
    create table(:evaluations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :value, :decimal, null: false
      add :type, :string
      add :description, :text

      timestamps()
    end
  end
end
