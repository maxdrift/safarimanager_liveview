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
        stats: slides_count_and_stats(competition_id)
      )

    {:noreply, socket}
  end

  defp slides_count_and_stats(competition_id) do
    slides_count_by_camera_type = Slides.count_for_jury_by_camera_type(competition_id)
    slides_count_by_category = Slides.count_for_jury_by_category(competition_id)
    {slides_count, species_count} = Slides.count_for_jury(competition_id)

    camera_type_stats =
      Enum.map(slides_count_by_camera_type, fn {camera_type, {slides_count, species_count}} ->
        {camera_type,
         %{
           name: camera_type_label(camera_type),
           slides_count: slides_count,
           species_count: species_count
         }}
      end)
      |> Enum.into(%{})

    category_stats =
      Enum.map(slides_count_by_category, fn {category_id,
                                             {category_name, slides_count, species_count}} ->
        {category_id,
         %{
           name: category_name,
           slides_count: slides_count,
           species_count: species_count
         }}
      end)
      |> Enum.into(%{})

    %{
      all: %{
        name: gettext("all"),
        slides_count: slides_count,
        species_count: species_count
      },
      camera_type: camera_type_stats,
      category: category_stats
    }
  end

  defp camera_type_label(:reflex), do: gettext("reflex")
  defp camera_type_label(:compact), do: gettext("compact")
  defp camera_type_label(:any), do: gettext("any")
  defp camera_type_label(other), do: Gettext.gettext(SMWeb.Gettext, other)
end
