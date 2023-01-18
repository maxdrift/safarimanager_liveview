defmodule SMWeb.Atoms.TableRow do
  @moduledoc """
  Table row component
  """
  use SMWeb, :surface_component

  prop entity, :struct, required: true

  slot default, required: true

  def render(assigns) do
    ~F"""
    <tr>
      <th>{@entity.id |> String.split_at(7) |> Tuple.to_list() |> hd()}</th>
      <td>{@entity.name}</td>
      <td>{@entity.inserted_at |> DateTime.truncate(:second) |> DateTime.to_string()}</td>
      <td>{@entity.updated_at |> DateTime.truncate(:second) |> DateTime.to_string()}</td>
      <td>
        <#slot />
      </td>
    </tr>
    """
  end
end
