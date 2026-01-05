defmodule SMWeb.Components.SlidesSelectionList do
  @moduledoc """
  Slides selection list component.
  """
  use SMWeb, :component

  alias SM.Utils

  attr :jury_slides, :list, default: []
  attr :fixed_slides, :list, default: []
  attr :discarded_slides, :list, default: []

  def slides_selection_list(assigns) do
    ~H"""
    <div id="selection-jury-section" x-data="{ expanded: true }">
      <div
        id="selection-jury-header"
        class="alert alert-success alert-sm my-2"
        @click="expanded = ! expanded"
      >
        <span class="text-xl mx-auto">
          {gettext("Selected for Jury")} (<span id="jury-slides-count">{Enum.count(@jury_slides)}</span>)
        </span>
        <span>
          <svg
            x-show="!expanded"
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 inline-block mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
          <svg
            x-show="expanded"
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 inline-block mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
          </svg>
        </span>
      </div>
      <div class="max-h-96 overflow-y-auto mt-2 tiny-scrollbar" x-show="expanded" x-collapse>
        <table class="table table-zebra table-fixed w-full">
          <!-- head -->
          <thead>
            <tr>
              <th class="sticky top-0 w-1/12" />
              <th class="sticky top-0 w-auto">{gettext("File name")}</th>
              <th class="sticky top-0 w-auto">{gettext("Size")}</th>
              <th class="sticky top-0 w-auto">{gettext("Subject")}</th>
              <th class="sticky top-0 w-auto" />
            </tr>
          </thead>
          <tbody>
            <tr :if={@jury_slides == []}>
              <td colspan="5">{gettext("No slides selected for Jury")}.</td>
            </tr>

            <tr :for={slide <- @jury_slides}>
              <td class="truncate">
                <div>
                  <div class="w-20">
                    <img src={Utils.slide_thumbnail_path(slide)} class="rounded-md border" />
                  </div>
                </div>
              </td>
              <td class="truncate">{slide.file_name}</td>
              <td class="truncate">{Utils.format_bytes(slide.file_size)}</td>
              <td>
                <span class="capitalize">
                  {(slide.subject && slide.subject.name) || gettext("N/A")}
                </span>
                <br />
                <span class="text-xs italic">
                  {(slide.subject && slide.subject.scientific_name) || gettext("N/A")}
                </span>
              </td>
              <td>
                <button
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
    <div id="selection-fixed-section" x-data="{ expanded: false }">
      <div
        id="selection-fixed-header"
        class="alert alert-warning alert-sm my-2"
        @click="expanded = ! expanded"
      >
        <span class="text-xl mx-auto">
          {gettext("Fixed points")} (<span id="fixed-slides-count">{Enum.count(@fixed_slides)}</span>)
        </span>
        <span>
          <svg
            x-show="!expanded"
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 inline-block mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
          <svg
            x-show="expanded"
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 inline-block mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
          </svg>
        </span>
      </div>
      <div class="max-h-96 overflow-y-auto mt-2 tiny-scrollbar" x-show="expanded" x-collapse>
        <table class="table table-zebra table-fixed w-full">
          <!-- head -->
          <thead>
            <tr>
              <th class="sticky top-0 w-1/12" />
              <th class="sticky top-0 w-auto">{gettext("File name")}</th>
              <th class="sticky top-0 w-auto">{gettext("Size")}</th>
              <th class="sticky top-0 w-auto">{gettext("Subject")}</th>
              <th class="sticky top-0 w-auto" />
            </tr>
          </thead>
          <tbody>
            <tr :if={@fixed_slides == []}>
              <td colspan="5">{gettext("No slides selected for fixed points")}.</td>
            </tr>
            <tr :for={slide <- @fixed_slides}>
              <td class="truncate">
                <div>
                  <div class="w-20">
                    <img src={Utils.slide_thumbnail_path(slide)} class="rounded-md border" />
                  </div>
                </div>
              </td>
              <td class="truncate">{slide.file_name}</td>
              <td class="truncate">{Utils.format_bytes(slide.file_size)}</td>
              <td>
                <span class="capitalize">
                  {(slide.subject && slide.subject.name) || gettext("N/A")}
                </span>
                <br />
                <span class="text-xs italic">
                  {(slide.subject && slide.subject.scientific_name) || gettext("N/A")}
                </span>
              </td>
              <td>
                <button
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
    <div id="selection-discarded-section" x-data="{ expanded: false }">
      <div
        id="selection-discarded-header"
        class="alert alert-error alert-sm my-2"
        @click="expanded = ! expanded"
      >
        <span class="text-xl mx-auto">
          {ngettext("Discarded", "Discarded", Enum.count(@discarded_slides))} (<span id="discarded-slides-count">{Enum.count(
            @discarded_slides
          )}</span>)
        </span>
        <span>
          <svg
            x-show="!expanded"
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 inline-block mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
          <svg
            x-show="expanded"
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 inline-block mr-1"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
          </svg>
        </span>
      </div>
      <div class="max-h-96 overflow-y-auto mt-2 tiny-scrollbar" x-show="expanded" x-collapse>
        <table class="table table-zebra table-fixed w-full">
          <!-- head -->
          <thead>
            <tr>
              <th class="sticky top-0 w-1/12" />
              <th class="sticky top-0 w-auto">{gettext("File name")}</th>
              <th class="sticky top-0 w-auto">{gettext("Size")}</th>
              <th class="sticky top-0 w-auto">{gettext("Subject")}</th>
              <th class="sticky top-0 w-auto" />
            </tr>
          </thead>
          <tbody>
            <tr :if={@discarded_slides == []}>
              <td colspan="5">{gettext("No slides selected to be discarded.")}</td>
            </tr>
            <tr :for={slide <- @discarded_slides}>
              <td class="truncate">
                <div>
                  <div class="w-20">
                    <img src={Utils.slide_thumbnail_path(slide)} class="rounded-md border" />
                  </div>
                </div>
              </td>
              <td class="truncate">{slide.file_name}</td>
              <td class="truncate">{Utils.format_bytes(slide.file_size)}</td>
              <td>
                <span class="capitalize">
                  {(slide.subject && slide.subject.name) || gettext("N/A")}
                </span>
                <br />
                <span class="text-xs italic">
                  {(slide.subject && slide.subject.scientific_name) || gettext("N/A")}
                </span>
              </td>
              <td>
                <button
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
    """
  end
end
