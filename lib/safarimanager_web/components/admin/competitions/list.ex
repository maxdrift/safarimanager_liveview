defmodule SMWeb.Components.Admin.Competitions.List do
  @moduledoc """
  Competitions list component
  """
  use SMWeb, :surface_component

  alias Surface.Components.LivePatch

  prop items, :list, required: true
  prop all_selected?, :boolean, required: true
  prop any_selected?, :boolean, required: true
  prop select_one, :event, required: true
  prop select_all, :event, required: true
  prop delete_one, :event, required: true

  defp format_id(id) do
    id
    |> String.split_at(8)
    |> Tuple.to_list()
    |> hd()
  end

  defp value_or_na(nil), do: "N/A"
  defp value_or_na(value), do: value

  defp format_date(nil), do: "N/A"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
