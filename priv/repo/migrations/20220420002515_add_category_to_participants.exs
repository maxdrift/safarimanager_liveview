defmodule SM.Repo.Migrations.AddCategoryToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :category_id, references(:categories, on_delete: :nilify_all, type: :binary_id)
    end
  end
end
