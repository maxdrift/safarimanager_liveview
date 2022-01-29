defmodule SMWeb.Components.Dialog do
  @moduledoc """
  Dialog component
  """
  use Surface.Component

  prop id, :string, required: true

  prop show, :boolean, default: false

  slot default, required: true
end
