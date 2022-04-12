defmodule SM.Repo.Migrations.AddMetadataToSlides do
  use Ecto.Migration

  def change do
    alter table(:slides) do
      add :metadata, :map
      add :width, :integer
      add :height, :integer
    end
  end
end
