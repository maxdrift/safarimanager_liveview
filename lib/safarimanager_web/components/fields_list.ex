defmodule SMWeb.Components.FieldsList do
  @moduledoc """
  Fields list static component
  """

  use SMWeb, :surface_component

  slot list_items

  def render(assigns) do
    ~F"""
    <ul class="leading-loose">
      <li>
        {#for list_item <- @list_items}
          <#slot {list_item} />
        {/for}
      </li>
    </ul>
    """
  end
end
