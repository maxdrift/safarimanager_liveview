defmodule SMWeb.Components.Column do
  @moduledoc """
  Grid column component
  """

  use Surface.Component, slot: "cols"

  @doc "The column title"
  prop title, :string
  prop class, :css_class, default: []
end
