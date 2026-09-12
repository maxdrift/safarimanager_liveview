defmodule SMWeb.Live.JuryLauncher do
  @moduledoc """
  Jury launcher live view
  """
  use SMWeb, :live_view

  import SMWeb.Components.CompetitionHeader
  import SMWeb.Components.Layout
  import SMWeb.Components.StepsHeader

  alias SM.Competitions
  alias SM.Slides

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
      assign(socket,
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
      Map.new(slides_count_by_camera_type, fn {camera_type, {slides_count, species_count}} ->
        {camera_type, %{name: camera_type_label(camera_type), slides_count: slides_count, species_count: species_count}}
      end)

    category_stats =
      Map.new(slides_count_by_category, fn {category_id, {category_name, slides_count, species_count}} ->
        {category_id, %{name: category_name, slides_count: slides_count, species_count: species_count}}
      end)

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

  attr :id, :string, default: nil
  attr :button_id, :string, default: nil
  attr :name, :string, required: true
  attr :slides_count, :integer, required: true
  attr :species_count, :integer, required: true
  attr :href, :string, required: true
  attr :highlighted, :boolean, default: false

  defp jury_stat_card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "card bg-base-100 shadow",
        @highlighted && "ring-2 ring-primary"
      ]}
    >
      <div class="card-body items-center gap-2 p-4 text-center sm:gap-3 sm:p-6">
        <h3 class="text-lg font-semibold capitalize sm:text-2xl">{@name}</h3>
        <p class="text-sm text-base-content/80 sm:text-base">
          {@slides_count} {gettext("slides")}
        </p>
        <p class="text-xs text-base-content/60 sm:text-sm">
          {@species_count} {gettext("species")}
        </p>
        <div class="card-actions mt-2 w-full justify-center sm:mt-4">
          <.link
            id={@button_id}
            navigate={@href}
            class={[
              "btn btn-primary w-full sm:btn-lg sm:w-auto",
              @slides_count == 0 && "btn-disabled"
            ]}
          >
            {gettext("Start Jury")}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
