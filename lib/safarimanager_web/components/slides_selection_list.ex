defmodule SMWeb.Components.SlidesSelectionList do
  @moduledoc """
  Slide selection groups using DaisyUI `collapse` + `collapse-open` (stock component).

  Titles use `phx-click` so open/close state lives on the LiveView and survives
  re-renders when slide lists update. This avoids Alpine `x-collapse`, which
  animates height and fights nested scroll containers.
  """
  use SMWeb, :component

  alias SM.Utils

  attr :jury_slides, :list, default: []
  attr :fixed_slides, :list, default: []
  attr :discarded_slides, :list, default: []
  attr :jury_expanded, :boolean, default: true
  attr :fixed_expanded, :boolean, default: false
  attr :discarded_expanded, :boolean, default: false

  def slides_selection_list(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 min-w-0">
      <div
        id="selection-jury-section"
        class={[
          "collapse collapse-arrow border border-success/40 bg-base-100 rounded-box shadow-sm [&_.collapse-title::after]:!top-1/2 [&_.collapse-title::after]:!bottom-auto [&_.collapse-title::after]:!-translate-y-1/2",
          @jury_expanded && "collapse-open"
        ]}
      >
        <div
          id="selection-jury-header"
          class="collapse-title font-semibold text-base sm:text-lg text-success cursor-pointer flex min-h-12 items-center pt-3 py-0 ps-4 pe-10"
          phx-click="selection-section-toggle"
          phx-value-section="jury"
        >
          {gettext("Selected for Jury")} (<span id="jury-slides-count">{Enum.count(@jury_slides)}</span>)
        </div>
        <div class="collapse-content px-0 pb-3 min-w-0">
          <div class="overflow-x-auto py-3 px-2 sm:px-4 tiny-scrollbar">
            <table class="table table-sm sm:table-md table-zebra w-full">
              <thead>
                <tr class="bg-base-200/95">
                  <th class="w-16 sm:w-20" />
                  <th>{gettext("File name")}</th>
                  <th class="w-20 whitespace-nowrap">{gettext("Size")}</th>
                  <th class="min-w-0">{gettext("Subject")}</th>
                  <th class="w-24" />
                </tr>
              </thead>
              <tbody>
                <tr :if={@jury_slides == []}>
                  <td colspan="5" class="text-base-content/70">
                    {gettext("No slides selected for Jury")}.
                  </td>
                </tr>
                <tr :for={slide <- @jury_slides}>
                  <td class="whitespace-nowrap align-middle w-16 sm:w-20">
                    <div class="w-14 sm:w-16 shrink-0">
                      <img
                        src={Utils.slide_thumbnail_path(slide)}
                        class="rounded-md border border-base-300 w-full aspect-square object-cover"
                        alt=""
                      />
                    </div>
                  </td>
                  <td class="max-w-[9rem] sm:max-w-none truncate align-middle" title={slide.file_name}>
                    {slide.file_name}
                  </td>
                  <td class="whitespace-nowrap align-middle text-sm">
                    {Utils.format_bytes(slide.file_size)}
                  </td>
                  <td class="align-middle min-w-0 text-sm">
                    <span class="capitalize block truncate">
                      {(slide.subject && slide.subject.name) || gettext("N/A")}
                    </span>
                    <span class="text-xs italic text-base-content/70 block truncate">
                      {(slide.subject && slide.subject.scientific_name) || gettext("N/A")}
                    </span>
                  </td>
                  <td class="whitespace-nowrap align-middle">
                    <button
                      type="button"
                      class="btn btn-secondary btn-xs"
                      phx-click="start-editing"
                      phx-value-id={slide.id}
                    >
                      {gettext("Edit")}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div
        id="selection-fixed-section"
        class={[
          "collapse collapse-arrow border border-warning/40 bg-base-100 rounded-box shadow-sm [&_.collapse-title::after]:!top-1/2 [&_.collapse-title::after]:!bottom-auto [&_.collapse-title::after]:!-translate-y-1/2",
          @fixed_expanded && "collapse-open"
        ]}
      >
        <div
          id="selection-fixed-header"
          class="collapse-title font-semibold text-base sm:text-lg text-warning cursor-pointer flex min-h-12 items-center pt-3 py-0 ps-4 pe-10"
          phx-click="selection-section-toggle"
          phx-value-section="fixed"
        >
          {gettext("Fixed points")} (<span id="fixed-slides-count">{Enum.count(@fixed_slides)}</span>)
        </div>
        <div class="collapse-content px-0 pb-3 min-w-0">
          <div class="overflow-x-auto py-3 px-2 sm:px-4 tiny-scrollbar">
            <table class="table table-sm sm:table-md table-zebra w-full">
              <thead>
                <tr class="bg-base-200/95">
                  <th class="w-16 sm:w-20" />
                  <th>{gettext("File name")}</th>
                  <th class="w-20 whitespace-nowrap">{gettext("Size")}</th>
                  <th class="min-w-0">{gettext("Subject")}</th>
                  <th class="w-24" />
                </tr>
              </thead>
              <tbody>
                <tr :if={@fixed_slides == []}>
                  <td colspan="5" class="text-base-content/70">
                    {gettext("No slides selected for fixed points")}.
                  </td>
                </tr>
                <tr :for={slide <- @fixed_slides}>
                  <td class="whitespace-nowrap align-middle w-16 sm:w-20">
                    <div class="w-14 sm:w-16 shrink-0">
                      <img
                        src={Utils.slide_thumbnail_path(slide)}
                        class="rounded-md border border-base-300 w-full aspect-square object-cover"
                        alt=""
                      />
                    </div>
                  </td>
                  <td class="max-w-[9rem] sm:max-w-none truncate align-middle" title={slide.file_name}>
                    {slide.file_name}
                  </td>
                  <td class="whitespace-nowrap align-middle text-sm">
                    {Utils.format_bytes(slide.file_size)}
                  </td>
                  <td class="align-middle min-w-0 text-sm">
                    <span class="capitalize block truncate">
                      {(slide.subject && slide.subject.name) || gettext("N/A")}
                    </span>
                    <span class="text-xs italic text-base-content/70 block truncate">
                      {(slide.subject && slide.subject.scientific_name) || gettext("N/A")}
                    </span>
                  </td>
                  <td class="whitespace-nowrap align-middle">
                    <button
                      type="button"
                      class="btn btn-secondary btn-xs"
                      phx-click="start-editing"
                      phx-value-id={slide.id}
                    >
                      {gettext("Edit")}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div
        id="selection-discarded-section"
        class={[
          "collapse collapse-arrow border border-error/40 bg-base-100 rounded-box shadow-sm [&_.collapse-title::after]:!top-1/2 [&_.collapse-title::after]:!bottom-auto [&_.collapse-title::after]:!-translate-y-1/2",
          @discarded_expanded && "collapse-open"
        ]}
      >
        <div
          id="selection-discarded-header"
          class="collapse-title font-semibold text-base sm:text-lg text-error cursor-pointer flex min-h-12 items-center pt-3 py-0 ps-4 pe-10"
          phx-click="selection-section-toggle"
          phx-value-section="discarded"
        >
          {ngettext("Discarded", "Discarded", Enum.count(@discarded_slides))} (<span id="discarded-slides-count">{Enum.count(
            @discarded_slides
          )}</span>)
        </div>
        <div class="collapse-content px-0 pb-3 min-w-0">
          <div class="overflow-x-auto py-3 px-2 sm:px-4 tiny-scrollbar">
            <table class="table table-sm sm:table-md table-zebra w-full">
              <thead>
                <tr class="bg-base-200/95">
                  <th class="w-16 sm:w-20" />
                  <th>{gettext("File name")}</th>
                  <th class="w-20 whitespace-nowrap">{gettext("Size")}</th>
                  <th class="min-w-0">{gettext("Subject")}</th>
                  <th class="w-24" />
                </tr>
              </thead>
              <tbody>
                <tr :if={@discarded_slides == []}>
                  <td colspan="5" class="text-base-content/70">
                    {gettext("No slides selected to be discarded.")}
                  </td>
                </tr>
                <tr :for={slide <- @discarded_slides}>
                  <td class="whitespace-nowrap align-middle w-16 sm:w-20">
                    <div class="w-14 sm:w-16 shrink-0">
                      <img
                        src={Utils.slide_thumbnail_path(slide)}
                        class="rounded-md border border-base-300 w-full aspect-square object-cover"
                        alt=""
                      />
                    </div>
                  </td>
                  <td class="max-w-[9rem] sm:max-w-none truncate align-middle" title={slide.file_name}>
                    {slide.file_name}
                  </td>
                  <td class="whitespace-nowrap align-middle text-sm">
                    {Utils.format_bytes(slide.file_size)}
                  </td>
                  <td class="align-middle min-w-0 text-sm">
                    <span class="capitalize block truncate">
                      {(slide.subject && slide.subject.name) || gettext("N/A")}
                    </span>
                    <span class="text-xs italic text-base-content/70 block truncate">
                      {(slide.subject && slide.subject.scientific_name) || gettext("N/A")}
                    </span>
                  </td>
                  <td class="whitespace-nowrap align-middle">
                    <button
                      type="button"
                      class="btn btn-secondary btn-xs"
                      phx-click="start-editing"
                      phx-value-id={slide.id}
                    >
                      {gettext("Edit")}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
