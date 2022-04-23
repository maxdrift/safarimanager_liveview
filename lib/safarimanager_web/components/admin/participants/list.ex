defmodule SMWeb.Components.Admin.Participants.List do
  @moduledoc """
  Participants list component
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
    |> String.split_at(7)
    |> Tuple.to_list()
    |> hd()
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %I:%M:%S %P %Z")
  end
end
