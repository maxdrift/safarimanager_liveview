defmodule SM.Repo.Migrations.AddPenaltyToSlides do
  use Ecto.Migration

  def change do
    alter table(:slides) do
      add :penalty, :boolean, default: false
    end
  end
end
