defmodule SMWeb.Components.ShortUUID do
  @moduledoc """
  Short UUID representation static component
  """

  use SMWeb, :component

  attr :value, :string, required: true

  def short_uuid(assigns) do
    ~H"""
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
