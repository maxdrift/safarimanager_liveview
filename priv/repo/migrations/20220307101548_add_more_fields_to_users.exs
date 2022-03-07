defmodule SM.Repo.Migrations.AddMoreFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :organization_id, references(:organizations)
      add :first_name, :string
      add :last_name, :string
    end
  end
end
