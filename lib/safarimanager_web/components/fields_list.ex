defmodule SMWeb.Components.FieldsList do
  @moduledoc """
  Fields list static component
  """

  use SMWeb, :component

  slot :fields_list_item, doc: "Fields list item" do
    attr :label, :string, required: true
  end

  def fields_list(assigns) do
    ~H"""
    <ul class="leading-loose">
      <li :for={list_item <- @fields_list_item}>
        <b>{list_item.label}:</b>
        {render_slot(list_item)}
      </li>
    </ul>
    """
  end
end
