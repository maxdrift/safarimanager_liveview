defmodule SM.Repo.Migrations.CreateJurors do
  use Ecto.Migration

  def change do
    create table(:jurors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:jurors, [:user_id])
    create index(:jurors, [:competition_id])
    create unique_index(:jurors, [:user_id, :competition_id])
  end
end
