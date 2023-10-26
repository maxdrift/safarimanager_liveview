defmodule SM.Repo.Migrations.RenameBooleanValueToIsPenaltyInEvaluations do
  use Ecto.Migration

  def change do
    rename table(:evaluations), :boolean_value, to: :is_penalty
  end
end
