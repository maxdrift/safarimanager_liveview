defmodule SMWeb.Atoms.Navbar do
  @moduledoc """
  Navbar component
  """
  use SMWeb, :surface_component

  prop title, :string

  slot default, required: true
end
