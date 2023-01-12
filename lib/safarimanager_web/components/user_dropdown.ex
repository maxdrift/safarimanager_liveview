defmodule SMWeb.Components.UserDropdown do
  @moduledoc """
  User dropdown component.
  """
  use SMWeb, :surface_component

  alias SMWeb.Components.UserAvatar
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

  prop user, :struct

  def render(assigns) do
    ~F"""
    <div title={gettext("User options")} class="dropdown dropdown-right dropdown-end">
      <label
        tabindex="0"
        class="mt-6 flex items-center group border-l-4 border-transparent"
        aria_label="user profile"
        phx-click={show_current_user_modal()}
      >
        <div class="w-[56px] flex justify-center">
          <UserAvatar
            user={@user}
            class="w-8 h-8 group-hover:ring-white group-hover:ring-2"
            text_class="text-xs"
          />
        </div>
        <span class="text-sm text-gray-400 font-medium group-hover:text-white">
          {@user && "#{@user.first_name} #{@user.last_name}"}
        </span>
      </label>
      <ul class="menu dropdown-content bg-base-200 text-base-content rounded-t rounded-b top-px w-52 overflow-y-auto shadow-2xl ml-[-3em]">
        <li>
          <LiveRedirect to={~p"/users/settings"}>
            {gettext("Settings")}
          </LiveRedirect>
        </li>
        <li>
          <Link to={~p"/users/log_out"} method={:delete}>
            {gettext("Log out")}
          </Link>
        </li>
      </ul>
    </div>
    """
  end

  defp show_current_user_modal do
    ""
  end
end
