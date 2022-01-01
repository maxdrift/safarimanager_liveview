defmodule SMWeb.Atoms.JuryToolbarButton do
  @moduledoc """
  Jury toolbar button component
  """
  use Surface.Component

  @doc "Button ID"
  prop id, :string

  @doc "Triggers on click"
  prop click, :event
  prop click_key, :string
  prop click_value, :string

  @doc "The content of the button"
  slot default, required: true
end
