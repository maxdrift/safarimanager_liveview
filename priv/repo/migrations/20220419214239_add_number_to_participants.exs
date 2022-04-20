defmodule SM.Repo.Migrations.AddNumberToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      # TODO: Switch 'null: true' to 'null: false' before release.
      add :number, :integer, null: true
    end

    create unique_index(:participants, [:competition_id, :number])
  end
end
