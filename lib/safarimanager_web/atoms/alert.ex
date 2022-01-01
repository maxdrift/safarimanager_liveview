defmodule SMWeb.Atoms.Alert do
  @moduledoc """
  Alert message component
  """
  use Surface.Component

  prop message, :string, required: true
  prop level, :string, values!: ["info", "success", "warning", "error"], default: "info"
  prop show, :boolean, default: false
end
