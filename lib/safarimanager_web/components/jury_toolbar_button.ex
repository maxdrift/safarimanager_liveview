defmodule SMWeb.Components.JuryToolbarButton do
  @moduledoc """
  Jury toolbar button component
  """
  use SMWeb, :surface_component

  @doc "Button ID"
  prop id, :string

  @doc "Triggers on click"
  prop click, :event
  prop click_key, :string
  prop click_value, :string
  prop title, :string
  prop class, :css_class, default: "btn btn-sm"

  @doc "The content of the button"
  slot default, required: true

  def render(assigns) do
    ~F"""
    <button
      id={@id}
      :on-click={@click}
      :values={%{@click_key => @click_value}}
      class={@class}
      {=@title}
    >
      <#slot />
    </button>
    """
  end
end
