defmodule SMWeb.Atoms.JuryToolbarButton do
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
  prop class, :css_class, default: "btn btn-sm"

  @doc "The content of the button"
  slot default, required: true
end
