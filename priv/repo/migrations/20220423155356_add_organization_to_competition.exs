defmodule SM.Repo.Migrations.AddOrganizationToCompetition do
  use Ecto.Migration

  def change do
    alter table(:competitions) do
      add :organization_id, references(:organizations, on_delete: :nilify_all, type: :binary_id)
    end
  end
end
