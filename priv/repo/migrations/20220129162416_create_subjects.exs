defmodule SM.Repo.Migrations.CreateSubjects do
  use Ecto.Migration

  def change do
    create table(:subjects, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :numeric_id, :integer
      add :scientific_name, :string
      add :coefficient, :integer
      add :type, :string

      timestamps()
    end

    create unique_index(:subjects, [:numeric_id])
  end
end
