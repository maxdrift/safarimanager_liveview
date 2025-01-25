defmodule SMWeb.Components.SidebarLink do
  @moduledoc """
  Sidebar link component.
  """
  use SMWeb, :component

  attr :label, :string, required: true
  attr :hero_icon, :string, required: true
  attr :to, :string, required: true
  attr :current, :string, required: true

  def sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "h-7",
        "flex",
        "items-center",
        "hover:bg-primary",
        "hover:text-primary-content",
        "hover:primary-content",
        "border-l-4",
        @to == @current && "text-primary",
        @to == @current && "border-primary",
        @to != @current && "text-base-content",
        @to != @current && "border-transparent"
      ]}
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
