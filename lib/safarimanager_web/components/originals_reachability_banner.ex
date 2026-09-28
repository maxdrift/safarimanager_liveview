defmodule SMWeb.Components.OriginalsReachabilityBanner do
  @moduledoc false
  use SMWeb, :component

  attr :status, :atom, required: true
  attr :competition_id, :string, default: nil

  def originals_reachability_banner(assigns) do
    ~H"""
    <div
      :if={@status == :unreachable and @competition_id}
      id="originals-unreachable-banner"
      role="status"
      aria-live="polite"
      class="shrink-0 border-b border-warning/40 bg-warning/15 text-base-content px-4 py-3"
    >
      <div class="container mx-auto flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p class="text-sm font-medium flex items-start gap-2">
          <Heroicons.icon
            name="exclamation-triangle"
            type="outline"
            class="w-5 h-5 shrink-0 text-warning"
          />
          {gettext(
            "Original slide images for this competition are unreachable. Thumbnails and previews may be shown instead."
          )}
        </p>
        <div class="flex flex-wrap gap-2 shrink-0">
          <button
            id="originals-retry"
            type="button"
            class="btn btn-warning btn-sm"
            phx-click="originals-retry"
            phx-disable-with={gettext("Checking…")}
          >
            {gettext("Retry")}
          </button>
          <.link
            id="originals-locate"
            navigate={~p"/organize/#{@competition_id}/slides"}
            class="btn btn-outline btn-sm"
          >
            {gettext("Locate folder")}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
