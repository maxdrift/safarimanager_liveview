defmodule SM.Repo.Migrations.AddNumberToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :number, :integer, null: false
    end

    create unique_index(:participants, [:competition_id, :number])
  end
end
