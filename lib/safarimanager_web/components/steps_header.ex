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
      %{
        name: gettext("Participants"),
        url: Path.join([@root_url, competition_id, "/participants"])
      },
      %{name: gettext("Jurors"), url: Path.join([@root_url, competition_id, "/jurors"])},
      %{name: gettext("Slides"), url: Path.join([@root_url, competition_id, "/slides"])},
      %{
        name: gettext("Selection"),
        url: Path.join([@root_url, competition_id, "/slide_selection"])
      },
      %{
        name: gettext("Validation"),
        url: Path.join([@root_url, competition_id, "/validation_launcher"])
      },
      %{name: gettext("Jury"), url: Path.join([@root_url, competition_id, "/jury_launcher"])},
      %{name: gettext("Results"), url: Path.join([@root_url, competition_id, "/results"])}
    ]
  end
end
