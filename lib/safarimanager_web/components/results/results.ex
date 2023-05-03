defmodule SMWeb.Results do
  @moduledoc """
  Results live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Results
  alias SM.Slides
  alias SM.Subjects
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

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
    {:ok, results} = Results.list(competition_id)
    {:ok, competition} = Competitions.get(competition_id)
    subjects = Subjects.list_with_coefficients(competition_id)
    slides_count = Slides.count_by_status(competition_id)
    subjects_count = Enum.count(subjects)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:results, results)
      |> assign(:subjects, subjects)
      |> assign(:subjects_count, subjects_count)
      |> assign(:slides_count, slides_count)
      |> assign(:penalties_count, Slides.count_penalties(competition_id))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _action], _result}, socket) do
    {:ok, results} = Results.list(socket.assigns.competition_id)

    socket =
      socket
      |> assign(:results, results)

    {:noreply, socket}
  end

  defp status_to_label(:submitted_fixed), do: "Fixed points"
  defp status_to_label(:submitted_jury), do: "Jury"
end
