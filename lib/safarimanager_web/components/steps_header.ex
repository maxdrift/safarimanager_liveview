defmodule SMWeb.Components.StepsHeader do
  @moduledoc """
  StepsHeader component.
  """
  use SMWeb, :surface_component

  prop current_step, :integer, required: true

  defp steps do
    [
      %{name: "Participants"},
      %{name: "Jurors"},
      %{name: "Slides"},
      %{name: "CSV"},
      %{name: "Jury"},
      %{name: "Results"}
    ]
  end
end
