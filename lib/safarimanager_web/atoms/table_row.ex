defmodule SMWeb.Atoms.TableRow do
  @moduledoc """
  Table row component
  """
  use SMWeb, :surface_component

  prop entity, :struct, required: true

  slot default, required: true
end
