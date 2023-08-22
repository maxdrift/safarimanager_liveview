defmodule SMWeb.Components.StepsHeader do
  @moduledoc """
  StepsHeader component.
  """
  use SMWeb, :surface_component

  prop competition, :string, required: true
  prop current_step, :atom, required: true

  @root_url "/organize"

  def render(assigns) do
    ~F"""
    <div class="pt-4 text-center hidden lg:block">
      <ul class="steps steps-horizontal">
        {#for step <- steps(@competition, @current_step)}
          <li class={"step", "step-primary": step.active}>
            <a href={step.url}>
              {step.name}
            </a>
          </li>
        {/for}
      </ul>
    </div>
    """
  end

  defp steps(competition, current_step) do
    [
      %{
        id: :participants,
        active: true,
        name: gettext("Participants"),
        url: Path.join([@root_url, competition.id, "/participants"])
      },
      %{
        id: :teams,
        active: true,
        name: gettext("Teams"),
        url: Path.join([@root_url, competition.id, "/teams"])
      },
      %{id: :jurors, active: true, name: gettext("Jurors"), url: Path.join([@root_url, competition.id, "/jurors"])},
      %{id: :slides, active: true, name: gettext("Slides"), url: Path.join([@root_url, competition.id, "/slides"])},
      %{
        id: :selection,
        active: true,
        name: gettext("Selection"),
        url: Path.join([@root_url, competition.id, "/slide_selection"])
      },
      %{
        id: :validation,
        active: true,
        name: gettext("Validation"),
        url: Path.join([@root_url, competition.id, "/validation_launcher"])
      },
      %{id: :jury, active: true, name: gettext("Jury"), url: Path.join([@root_url, competition.id, "/jury_launcher"])},
      %{
        id: :results,
        active: true,
        name: gettext("Results"),
        url: Path.join([@root_url, competition.id, results_path(competition)])
      }
    ]
    |> Enum.reject(&(!competition.for_teams && &1.id == :teams))
    |> Enum.map_reduce(true, fn
      %{id: ^current_step} = step, _tripped -> {%{step | active: true}, false}
      step, true -> {%{step | active: true}, true}
      step, false -> {%{step | active: false}, false}
    end)
    |> elem(0)
  end

  defp results_path(competition) do
    if competition.for_teams do
      "/team_results"
    else
      "/results"
    end
  end
end
