defmodule SM.Repo.Migrations.AddLocationToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :location, :string
    end
  end
end
