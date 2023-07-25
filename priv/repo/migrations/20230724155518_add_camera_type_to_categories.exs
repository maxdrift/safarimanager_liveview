defmodule SM.Repo.Migrations.AddCameraTypeToCategories do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :camera_type, :string, null: false, default: "any"
    end
  end
end
