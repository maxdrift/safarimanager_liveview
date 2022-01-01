defmodule SMWeb.Atoms.TableRow do
  @moduledoc """
  Table row component
  """
  use Surface.Component

  prop entity, :struct, required: true

  slot default, required: true
end
