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
    <div class="flex grow h-full min-h-0">
      <div
        data-el-sidebar-backdrop
        class="hidden fixed inset-0 z-[650] bg-base-content/30 md:hidden"
        aria-hidden="true"
        phx-click={close_mobile_sidebar()}
      />
      <div class="max-md:w-0 max-md:overflow-visible md:static md:h-full md:z-[600]">
        <.sidebar current_page={@current_page} current_user={@current_user} />
      </div>
      <div class="flex flex-col grow min-w-0 min-h-0">
        <header class="flex md:hidden shrink-0 items-center justify-between h-14 px-4 z-[700] bg-base-100 border-b border-base-300 text-base-content">
          <button
            type="button"
            data-el-sidebar-open
            aria-label={gettext("Open menu")}
            class="inline-flex items-center justify-center rounded-lg p-2 text-base-content hover:bg-base-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary"
            phx-click={open_mobile_sidebar()}
          >
            <Heroicons.icon name="bars-3" type="solid" class="h-6 w-6" />
          </button>

          <div class="text-base-content/80 hover:text-base-content focus:text-base-content">
            <%= if @topbar_action do %>
              {render_slot(@topbar_action)}
            <% else %>
              <.link href={~p"/"} class="flex items-center">
                <Heroicons.icon name="home" type="solid" class="h-5 w-5" />
                <span class="pl-2">{gettext("Home")}</span>
              </.link>
            <% end %>
          </div>
        </header>
        <div class="grow overflow-y-auto min-w-0">
          <div class="container mx-auto pt-5 px-5 min-w-0">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp open_mobile_sidebar do
    "max-md:hidden"
    |> JS.remove_class(to: "[data-el-sidebar]")
    |> JS.remove_class("hidden", to: "[data-el-sidebar-backdrop]")
  end

  defp close_mobile_sidebar do
    "max-md:hidden"
    |> JS.add_class(to: "[data-el-sidebar]")
    |> JS.add_class("hidden", to: "[data-el-sidebar-backdrop]")
  end
end
