defmodule SMWeb.Components.FieldsListItem do
  @moduledoc """
  Fields list item static component
  """
  use Surface.Component, slot: "list_items"

  prop label, :string, required: true

  slot default, required: true

  def render(assigns) do
    ~F"""
    <li>
      <b>
        {@label}:
      </b>
      <#slot />
    </li>
    """
  end
end
