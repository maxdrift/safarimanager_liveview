defmodule SMWeb.Components.SidebarLink do
  @moduledoc """
  Sidebar link component.
  """
  use SMWeb, :surface_component

  prop label, :string, required: true
  prop hero_icon, :string, required: true
  prop to, :string, required: true
  prop current, :string, required: true

  def render(assigns) do
    ~F"""
    <.link
      navigate={@to}
      class={
        "h-7",
        "flex",
        "items-center",
        "hover:bg-primary",
        "hover:text-primary-content",
        "hover:primary-content",
        "border-l-4",
        "text-primary": @to == @current,
        "border-primary": @to == @current,
        "text-base-content": @to != @current,
        "border-transparent": @to != @current
      }
    >
      <Heroicons.icon
        name={@hero_icon}
        type="outline"
        class="h-6 text-md leading-6 w-[56px] flex justify-center"
      />
      <span class="text-sm font-medium">
        {@label}
      </span>
    </.link>
    """
  end
end
