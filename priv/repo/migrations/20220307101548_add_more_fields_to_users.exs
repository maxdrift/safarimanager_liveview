defmodule SM.Repo.Migrations.AddMoreFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :organization_id, references(:organizations, on_delete: :nillify, type: :binary_id)
      add :first_name, :string
      add :last_name, :string
    end
  end
end
