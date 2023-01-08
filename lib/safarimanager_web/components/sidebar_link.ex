defmodule SMWeb.Components.SidebarLink do
  @moduledoc """
  Sidebar link component.
  """
  use SMWeb, :surface_component

  alias Surface.Components.LiveRedirect

  prop label, :string, required: true
  prop hero_icon, :string, required: true
  prop to, :string, required: true
  prop current, :string, required: true

  def render(assigns) do
    ~F"""
    <LiveRedirect
      to={@to}
      class={
        "h-7",
        "flex",
        "items-center",
        "hover:text-white",
        "border-l-4",
        "hover:border-white",
        "text-white": @to == @current,
        "text-gray-400": @to != @current,
        "border-white": @to == @current,
        "border-transparent": @to != @current
      }
    >
      <Heroicons.Surface.Icon
        name={@hero_icon}
        type="outline"
        class="h-6 text-md leading-6 w-[56px] flex justify-center"
      />
      <span class="text-sm font-medium">
        {@label}
      </span>
    </LiveRedirect>
    """
  end
end
