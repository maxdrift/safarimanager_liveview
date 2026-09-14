defmodule SMWeb.Components.ThemeChangeDropdown do
  @moduledoc """
  Theme change dropdown component.
  """
  use SMWeb, :component

  import SMWeb.Components.ThemeChangeDropdownItem

  attr :themes, :list,
    default:
      ~w(light dark cupcake bumblebee emerald corporate synthwave retro cyberpunk valentine halloween garden forest aqua lofi pastel fantasy wireframe black luxury dracula cmyk autumn business acid lemonade night coffee winter)

  def theme_change_dropdown(assigns) do
    ~H"""
    <details title={gettext("Change theme")} class="dropdown dropdown-right dropdown-end">
      <summary
        aria-label="change theme"
        class="mt-2 h-7 flex items-center list-none text-base-content hover:text-primary-content border-l-4 border-transparent hover:bg-primary cursor-pointer"
      >
        <Heroicons.icon
          name="swatch"
          type="outline"
          class="h-6 text-md leading-6 w-[56px] flex justify-center"
        />
        <span class="text-sm font-medium">
          {gettext("Theme")}
        </span>
        <Heroicons.icon
          name="chevron-down"
          type="outline"
          class="ml-3 hidden h-4 w-4 sm:inline-block"
        />
      </summary>
      <div class="dropdown-content bg-base-100 text-base-content rounded-t rounded-b top-px max-h-96 h-[70vh] w-52 overflow-y-auto shadow-2xl ml-[1em] z-50">
        <div class="grid grid-cols-1 gap-3 p-3">
          <.theme_change_dropdown_item :for={theme <- @themes} theme={theme} />
        </div>
      </div>
    </details>
    """
  end
end
