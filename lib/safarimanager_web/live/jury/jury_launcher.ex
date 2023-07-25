defmodule SMWeb.Live.JuryLauncher do
  @moduledoc """
  Jury launcher live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Slides
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(
        competition_id: competition_id,
        competition: competition,
        camera_types: Competitions.list_camera_types(competition_id),
        slides_count_by_camera_type: Slides.count_for_jury_by_camera_type(competition_id),
        slides_count: Slides.count_for_jury(competition_id)
      )

    {:noreply, socket}
  end

  defp camera_type_label(:reflex), do: gettext("reflex")
  defp camera_type_label(:compact), do: gettext("compact")
  defp camera_type_label(:any), do: gettext("any")
  defp camera_type_label(other), do: Gettext.gettext(SMWeb.Gettext, other)
end
