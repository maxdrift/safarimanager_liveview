defmodule SMWeb.Components.Layout do
  @moduledoc """
  Layout component.
  """
  use SMWeb, :component

  import SMWeb.Components.Sidebar

  attr :current_page, :string, required: true
  attr :current_user, SM.Accounts.User

  slot :topbar_action
  slot :inner_block, required: true

  def layout(assigns) do
    ~H"""
    <div class="flex grow h-full">
      <div class="absolute md:static h-full z-[600]">
        <!-- <.live_region role="alert" /> -->
        <.sidebar current_page={@current_page} current_user={@current_user} />
      </div>
      <div class="grow overflow-y-auto">
        <div class="md:hidden sticky flex items-center justify-between h-14 px-4 top-0 left-0 z-[500] bg-white border-b border-gray-200">
          <div class="pt-1 text-xl text-gray-500 hover:text-gray-600 focus:text-gray-600">
            <button
              data-el-toggle-sidebar
              aria-label="show sidebar"
              phx-click={
                JS.remove_class("hidden", to: "[data-el-sidebar]")
                |> JS.toggle(to: "[data-el-toggle-sidebar]")
              }
            >
              <Heroicons.icon name="bars-3" type="solid" />
            </button>
          </div>

          <div class="text-gray-400 hover:text-gray-600 focus:text-gray-600">
            <%= if @topbar_action do %>
              {render_slot(@topbar_action)}
            <% else %>
              <.link href={~p"/"} class="flex items-center">
                <Heroicons.icon name="home" type="solid" />
                <span class="pl-2">Home</span>
              </.link>
            <% end %>
          </div>
        </div>
        <div class="container mx-auto pt-5 px-5">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end
end
