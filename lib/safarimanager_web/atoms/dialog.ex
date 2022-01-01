defmodule SMWeb.Components.Dialog do
  use Surface.Component

  prop id, :string, required: true

  prop show, :boolean, default: false

  slot default, required: true
  slot actions
end
