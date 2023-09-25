defmodule SM.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :organization_name, :string
      add :number, :integer, null: false
      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create unique_index(:teams, [:competition_id, :number])
  end
end
