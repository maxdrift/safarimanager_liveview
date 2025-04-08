defmodule SMWeb.Components.JuryToolbarButton do
  @moduledoc """
  Jury toolbar button component
  """
  use SMWeb, :component

  attr :id, :string
  attr :click, :string
  attr :click_key, :string
  attr :click_value, :string
  attr :title, :string
  attr :class, :any, default: "btn btn-sm"

  slot :inner_block

  def jury_toolbar_button(%{click_key: _key} = assigns) do
    ~H"""
    <button
      id={@id}
      phx-click={@click}
      phx-value-{@click_key}={@click_value}
      class={@class}
      title={@title}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def jury_toolbar_button(%{click: _click} = assigns) do
    ~H"""
    <button id={@id} phx-click={@click} class={@class} title={@title}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  def jury_toolbar_button(assigns) do
    ~H"""
    <button id={@id} class={@class} title={@title}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
