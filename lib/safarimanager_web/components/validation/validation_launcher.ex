defmodule SMWeb.ValidationLauncher do
  @moduledoc """
  Validation launcher live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Slides
  alias SM.Subjects
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

  require Logger

  # data user, :struct

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:flagged_slides, [])
      |> assign(:subjects, Subjects.list())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:flagged_slides, Slides.list_flagged(competition_id))

    {:noreply, socket}
  end

  # Internal

  defp subject_name(subjects, subject_id) do
    Enum.find_value(subjects, "N/A", fn s ->
      if s.id == subject_id, do: s.name
    end)
  end

  defp status_to_label(:submitted_fixed), do: "Fixed points"
  defp status_to_label(:submitted_jury), do: "Jury"
end
