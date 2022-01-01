defmodule SMWeb.Atoms.Navbar do
  @moduledoc """
  Navbar component
  """
  use Surface.Component

  prop title, :string

  slot default, required: true
end
