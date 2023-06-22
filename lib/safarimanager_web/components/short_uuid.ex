defmodule SMWeb.Components.ShortUUID do
  @moduledoc """
  Short UUID representation static component
  """

  use SMWeb, :surface_component

  prop value, :string, required: true

  def render(assigns) do
    ~F"""
    {format_id(@value)}
    """
  end

  defp format_id(id) do
    id
    |> String.split_at(8)
    |> Tuple.to_list()
    |> hd()
  end
end
