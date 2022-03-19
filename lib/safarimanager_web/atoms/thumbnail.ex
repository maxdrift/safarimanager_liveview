defmodule SMWeb.Molecules.Thumbnail do
  @moduledoc """
  A single gallery image.
  """
  use SMWeb, :surface_component

  alias Surface.Components.LiveRedirect

  prop click, :event
  prop url, :string, required: true
  prop width, :integer, required: true
  prop height, :integer, required: true
end
