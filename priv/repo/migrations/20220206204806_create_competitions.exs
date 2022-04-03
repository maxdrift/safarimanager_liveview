defmodule SM.Repo.Migrations.CreateCompetitions do
  use Ecto.Migration

  def change do
    create table(:competitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :start_time, :utc_datetime_usec
      add :end_time, :utc_datetime_usec
      add :street_name, :string
      add :street_number, :string
      add :postal_code, :string
      add :city, :string
      add :state, :string
      add :country, :string
      add :allowed_evaluations, {:array, :binary_id}, default: []
      add :evaluations_per_juror, :integer, default: 0
      add :req_jurors_count, :integer, default: 0

      timestamps()
    end
  end
end
