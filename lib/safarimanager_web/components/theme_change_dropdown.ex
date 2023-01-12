defmodule SMWeb.Components.ThemeChangeDropdown do
  @moduledoc """
  Theme change dropdown component.
  """
  use SMWeb, :surface_component

  alias SMWeb.Components.ThemeChangeDropdownItem

  prop themes, :list,
    default:
      ~w(light dark cupcake bumblebee emerald corporate synthwave retro cyberpunk valentine halloween garden forest aqua lofi pastel fantasy wireframe black luxury dracula cmyk autumn business acid lemonade night coffee winter)

  def render(assigns) do
    ~F"""
    <div title={gettext("Change theme")} class="dropdown dropdown-right dropdown-end">
      <label
        tabindex="0"
        aria-label="change theme"
        class="mt-2 h-7 flex items-center text-gray-400 hover:text-white border-l-4 border-transparent hover:border-white"
      >
        <Heroicons.Surface.Icon
          name="swatch"
          type="outline"
          class="h-6 text-md leading-6 w-[56px] flex justify-center"
        />
        <span class="text-sm font-medium">
          {gettext("Theme")}
        </span>
        <Heroicons.Surface.Icon
          name="chevron-down"
          type="outline"
          class="ml-3 hidden h-4 w-4 sm:inline-block"
        />
      </label>
      <div class="dropdown-content bg-base-200 text-base-content rounded-t rounded-b top-px max-h-96 h-[70vh] w-52 overflow-y-auto shadow-2xl ml-[-6em]">
        <div class="grid grid-cols-1 gap-3 p-3" tabindex="0">
          {#for theme <- @themes}
            <ThemeChangeDropdownItem theme={theme} />
          {/for}
        </div>
      </div>
    </div>
    """
  end
end
