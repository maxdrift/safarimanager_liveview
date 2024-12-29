defmodule SMWeb.Live.TeamResults do
  @moduledoc """
  Results live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Results
  alias SM.Slides
  alias SM.Subjects
  alias SM.Teams
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = if connected?(socket), do: Slides.subscribe()
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event(event_name, params, socket) do
    Logger.debug("#{inspect({event_name, params})}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, results} = Results.list_for_teams(competition_id)
    {:ok, competition} = Competitions.get(competition_id)
    subjects = Subjects.list_with_coefficients(competition_id)
    slides_count = Slides.count_by_status(competition_id)
    subjects_count = Enum.count(subjects)

    socket =
      assign(socket,
        competition_id: competition_id,
        competition: competition,
        results: results,
        subjects: subjects,
        subjects_count: subjects_count,
        slides_count: slides_count,
        penalties_count: Slides.count_penalties(competition_id)
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _action], _result}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/organize/#{socket.assigns.competition_id}/team_results")}
  end

  defp status_to_label(:submitted_fixed), do: gettext("Fixed points")
  defp status_to_label(:submitted_jury), do: gettext("Jury")
  defp status_to_label(other), do: Gettext.gettext(SMWeb.Gettext, other)
end
