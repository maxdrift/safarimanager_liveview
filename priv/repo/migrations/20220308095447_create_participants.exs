defmodule SM.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id),
        primary_key: true

      timestamps()
    end

    create index(:participants, [:user_id])
    create index(:participants, [:competition_id])
  end
end
