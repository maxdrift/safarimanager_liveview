defmodule SM.Repo.Migrations.AddLinkedCompetitionOriginals do
  use Ecto.Migration

  def change do
    create table(:competition_directories, primary_key: false) do
      add :competition_id, references(:competitions, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :library_id, :binary_id, null: false
      add :root_path, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    alter table(:participants) do
      add :originals_folder, :string
    end

    alter table(:slides) do
      add :storage, :string, null: false, default: "internal"
    end
  end
end
