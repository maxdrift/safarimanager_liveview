defmodule SM.Repo.Migrations.CreateJurors do
  use Ecto.Migration

  def change do
    create table(:jurors, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      timestamps()
    end

    create index(:jurors, [:user_id])
    create index(:jurors, [:competition_id])
  end
end
