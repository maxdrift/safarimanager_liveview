defmodule SMWeb.Components.Sidebar do
  @moduledoc """
  Sidebar component.
  """
  use SMWeb, :surface_component

  alias SMWeb.Components.SidebarLink
  alias SMWeb.Components.ThemeChangeDropdown
  alias SMWeb.Components.UserDropdown

  prop current_page, :string, required: true
  prop current_user, :struct

  def render(assigns) do
    ~F"""
    <nav
      class="hidden md:flex w-[12rem] h-full py-2 md:py-5 base-300 border-r border-gray-600"
      aria-label="sidebar"
      data-el-sidebar
    >
      <button
        class="hidden text-xl text-base-content hover:text-white focus:text-white absolute top-4 right-3"
        aria-label="hide sidebar"
        data-el-toggle-sidebar
        phx-click={JS.add_class("hidden", to: "[data-el-sidebar]")
        |> JS.toggle(to: "[data-el-toggle-sidebar]")}
      >
        <Heroicons.icon name="bars-3" type="solid" />
      </button>

      <div class="flex flex-col justify-between h-full">
        <div class="flex flex-col">
          <div class="space-y-3">
            <div class="flex flex-col items-center">
              <.link href={~p"/"} class="flex items-center group">
                <img src={~p"/images/logo.png"} class="mx-2" height="40" width="40" alt="logo safari manager">
                <span class="text-base-content text-lg font-logo ml-[-1px] group-hover:text-white pt-1">
                  Safari Manager
                </span>
              </.link>
              <span class="text-base-content text-xs font-normal font-sans cursor-default w-full text-right">
                v{Application.spec(:safarimanager, :vsn)}
              </span>
            </div>
            <SidebarLink
              label={gettext("Home")}
              hero_icon="home"
              to={~p"/organize/new"}
              current={@current_page}
            />
            <div class="ml-4 border-t border-gray-600" />
            <div class="ml-6 h-7 flex items-center">
              <span class="text-base-content text-md font-semibold">
                {gettext("Admin")}
              </span>
            </div>
            <SidebarLink
              label={gettext("Organizations")}
              hero_icon="user-group"
              to={~p"/admin/organizations"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Subjects")}
              hero_icon="viewfinder-circle"
              to={~p"/admin/subjects"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Competitions")}
              hero_icon="trophy"
              to={~p"/admin/competitions"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Evaluations")}
              hero_icon="hand-thumb-up"
              to={~p"/admin/evaluations"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Users")}
              hero_icon="user"
              to={~p"/admin/users"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Categories")}
              hero_icon="tag"
              to={~p"/admin/categories"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Participants")}
              hero_icon="ticket"
              to={~p"/admin/participants"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Teams")}
              hero_icon="users"
              to={~p"/admin/teams"}
              current={@current_page}
            />
            <SidebarLink
              label={gettext("Import")}
              hero_icon="arrows-up-down"
              to={~p"/admin/import"}
              current={@current_page}
            />
          </div>
        </div>
        <div class="flex flex-col">
          <!-- TODO: hide if feature not available -->
          <button
            class="h-7 flex items-center text-base-content hover:text-primary-content border-l-4 border-transparent hover:bg-primary"
            aria-label="shutdown"
            phx-click={with_confirm(
              JS.push("shutdown"),
              title: gettext("Shut Down"),
              description: gettext("Are you sure you want to shut down Safari Manager now?"),
              confirm_text: gettext("Shut Down"),
              confirm_icon: "shut-down-line"
            )}
          >
            <Heroicons.icon
              name="power"
              type="solid"
              class="h-6 text-md leading-6 w-[56px] flex justify-center"
            />
            <span class="text-sm font-medium">
              {gettext("Shut Down")}
            </span>
          </button>
          <ThemeChangeDropdown />
          <UserDropdown user={@current_user} />
        </div>
      </div>
    </nav>
    """
  end

  defp with_confirm(action, _opts) do
    action
  end
end
