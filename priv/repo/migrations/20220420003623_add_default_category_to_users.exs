defmodule SM.Repo.Migrations.AddDefaultCategoryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :category_id, references(:categories, on_delete: :nilify_all, type: :binary_id)
    end
  end
end
