defmodule SM.Repo.Migrations.AddSlideFlagsTable do
  use Ecto.Migration

  def change do
    create table(:slide_flags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slide_id, references(:slides, on_delete: :delete_all, type: :binary_id)
      add :type, :string
      add :context, :map
      add :comment, :text
      add :resolved, :boolean, default: false

      timestamps()
    end

    create index(:slide_flags, [:slide_id, :type], unique: true)
  end
end
