defmodule SMWeb.Components.UserDropdown do
  @moduledoc """
  User dropdown component.
  """
  use SMWeb, :component

  import SMWeb.Components.UserAvatar

  attr :user, SM.Accounts.User

  def user_dropdown(assigns) do
    ~H"""
    <div title={gettext("User options")} class="dropdown dropdown-right dropdown-end">
      <label
        tabindex="0"
        class="mt-6 flex items-center group border-l-4 border-transparent"
        aria_label="user profile"
        phx-click={show_current_user_modal()}
      >
        <div class="w-[56px] flex justify-center">
          <.user_avatar
            user={@user}
            class={["w-8 h-8 group-hover:ring-primary group-hover:ring-2"]}
            text_class={["text-xs"]}
          />
        </div>
        <span class="text-sm text-base-content font-medium group-hover:text-primary">
          {@user && "#{@user.first_name} #{@user.last_name}"}
        </span>
      </label>
      <ul class="menu dropdown-content bg-base-200 text-base-content rounded-t rounded-b top-px w-52 overflow-y-auto shadow-2xl ml-[-3em]">
        <li>
          <.link navigate={~p"/users/settings"}>
            {gettext("Settings")}
          </.link>
        </li>
        <%!-- <li>
          <.link href={~p"/users/log_out"} method={:delete}>
            {gettext("Log out")}
          </.link>
        </li> --%>
      </ul>
    </div>
    """
  end

  defp show_current_user_modal do
    ""
  end
end
