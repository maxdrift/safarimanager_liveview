defmodule SM.Repo.Migrations.AddFlagsToSlides do
  use Ecto.Migration

  def change do
    alter table(:slides) do
      add :flags, :map
    end
  end
end
