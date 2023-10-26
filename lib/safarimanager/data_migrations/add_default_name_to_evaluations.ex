defmodule SM.DataMigrations.AddDefaultNameToEvaluations do
  @moduledoc """
  Update the Evaluations table adding default names
  """

  import Ecto.Query

  alias SM.Repo

  @doc """
  Copy `value` into `name` as string and insert a new "penalty" boolean evaluation
  """
  def up do
    {_count, nil} =
      Repo.update_all(
        from(
          e in "evaluations",
          update: [set: [name: e.value]]
        ),
        []
      )

    {_count, nil} =
      Repo.insert_all("evaluations", [
        %{
          id: Ecto.UUID.generate(),
          name: "P",
          value: "0",
          is_penalty: 1,
          type: :boolean,
          description: "Penalty",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ])
  end

  @doc """
  Remove the "penalty" evaluation and reset `name` fields to `nil`
  """
  def down do
    {_count, nil} =
      Repo.delete_all(
        from(
          "evaluations",
          where: [name: "P", value: "0", is_penalty: 1, type: "boolean", description: "Penalty"]
        )
      )

    {_count, nil} =
      Repo.update_all(
        from(
          "evaluations",
          update: [set: [name: nil]]
        ),
        []
      )
  end
end
