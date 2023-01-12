defmodule SMWeb.Components.Layout do
  @moduledoc """
  Layout component.
  """
  use SMWeb, :surface_component

  alias SMWeb.Components.Sidebar
  alias Surface.Components.LiveRedirect

  prop current_page, :string, required: true
  prop current_user, :struct

  slot topbar_action
  slot default, required: true

  def render(assigns) do
    ~F"""
    <div class="flex grow h-full">
      <div class="absolute md:static h-full z-[600]">
        <!-- <.live_region role="alert" /> -->
        <Sidebar current_page={@current_page} current_user={@current_user} />
      </div>
      <div class="grow overflow-y-auto">
        <div class="md:hidden sticky flex items-center justify-between h-14 px-4 top-0 left-0 z-[500] bg-white border-b border-gray-200">
          <div class="pt-1 text-xl text-gray-500 hover:text-gray-600 focus:text-gray-600">
            <button
              data-el-toggle-sidebar
              aria-label="show sidebar"
              phx-click={JS.remove_class("hidden", to: "[data-el-sidebar]")
              |> JS.toggle(to: "[data-el-toggle-sidebar]")}
            >
              <Heroicons.Surface.Icon name="bars-3" type="solid" />
            </button>
          </div>

          <div class="text-gray-400 hover:text-gray-600 focus:text-gray-600">
            <#slot {@topbar_action}>
              <LiveRedirect to={~p"/"} class="flex items-center">
                <Heroicons.Surface.Icon name="home" type="solid" />
                <span class="pl-2">Home</span>
              </LiveRedirect>
            </#slot>
          </div>
        </div>
        <#slot />
      </div>
    </div>
    """
  end
end
