defmodule SMWeb.Components.StepsHeader do
  @moduledoc """
  StepsHeader component.
  """
  use SMWeb, :surface_component

  prop competition_id, :string, required: true
  prop current_step, :integer, required: true

  @root_url "/organize"

  defp steps(competition_id) do
    [
      %{name: "Participants", url: Path.join([@root_url, competition_id, "/participants"])},
      %{name: "Jurors", url: Path.join([@root_url, competition_id, "/jurors"])},
      %{name: "Slides", url: Path.join([@root_url, competition_id, "/slides"])},
      %{name: "CSV", url: Path.join([@root_url, competition_id, "/csv_import"])},
      %{name: "Validation", url: Path.join([@root_url, competition_id, "/validation_launcher"])},
      %{name: "Jury", url: Path.join([@root_url, competition_id, "/jury_launcher"])},
      %{name: "Results", url: Path.join([@root_url, competition_id, "/results"])}
    ]
  end
end
