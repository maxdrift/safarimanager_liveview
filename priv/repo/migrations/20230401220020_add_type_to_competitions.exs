defmodule SM.Repo.Migrations.AddTypeToCompetitions do
  use Ecto.Migration

  def change do
    alter table(:competitions) do
      add :type, :string
    end
  end
end
