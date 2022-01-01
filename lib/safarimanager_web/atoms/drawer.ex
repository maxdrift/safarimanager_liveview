defmodule SMWeb.Atoms.Drawer do
  @moduledoc """
  Page drawer that shows the main menu and hides it on small screens
  """
  use Surface.Component

  slot default, required: true
  slot menu, required: true
end
