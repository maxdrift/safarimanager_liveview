defmodule SM.Repo.Migrations.CreateSlides do
  use Ecto.Migration

  def change do
    create table(:slides, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :competition_id, references(:competitions, on_delete: :delete_all, type: :binary_id)
      add :subject_id, references(:subjects, on_delete: :nilify_all, type: :binary_id)
      add :file_name, :string, null: false
      add :file_size, :integer, null: false
      add :file_type, :string
      add :file_hash, :string
      add :status, :string

      timestamps()
    end

    create index(:slides, [:user_id])
    create index(:slides, [:competition_id])
    create index(:slides, [:subject_id])
    create index(:slides, [:file_hash])
  end
end
